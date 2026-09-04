# Native Terraform tests. Run with `terraform test` from
# modules/iam-identity-center-permission-set/. Fully offline via mock_provider — see
# modules/s3-secure-bucket/tests/main.tftest.hcl for the fuller explanation of scope/limits.
#
# This module reads data.aws_ssoadmin_instances (a real AWS API call, not local computation),
# so it needs an explicit mock_data override — without one, a full provider mock would still
# fake a value for it, but not necessarily a usable one for tolist(...)[0].

mock_provider "aws" {
  mock_data "aws_ssoadmin_instances" {
    defaults = {
      arns = ["arn:aws:sso:::instance/ssoins-1234567890abcdef"]

      identity_store_ids = ["d-1234567890"]
    }
  }

  # aws_ssoadmin_managed_policy_attachment, aws_ssoadmin_permission_set_inline_policy,
  # aws_ssoadmin_permissions_boundary_attachment, and aws_ssoadmin_account_assignment all take
  # this permission set's .arn as a real, validated argument — a full provider mock fakes it
  # with a random non-ARN string otherwise, which fails client-side ARN format validation on
  # every one of those resources. See account-baseline's tests/main.tftest.hcl for the fuller
  # pattern this follows.
  mock_resource "aws_ssoadmin_permission_set" {
    defaults = {
      arn = "arn:aws:sso:::permissionSet/ssoins-1234567890abcdef/ps-1234567890abcdef"
    }
  }
}

run "creates_permission_set_with_expected_defaults" {
  command = apply

  variables {
    permission_set_name = "TestPermissionSet"

    target_account_ids = ["111111111111"]

    principal_id = "g-abc123456"
  }

  assert {
    condition = aws_ssoadmin_permission_set.this.name == "TestPermissionSet"

    error_message = "Permission set name should pass through from the variable unchanged."
  }

  assert {
    condition = aws_ssoadmin_permission_set.this.description == null

    error_message = "An empty description variable (the default) must result in a null description argument, not an empty string — AWS rejects an empty-string description (must be 1-700 chars if set at all)."
  }

  assert {
    condition = aws_ssoadmin_permission_set.this.session_duration == "PT4H"

    error_message = "session_duration should default to PT4H when not specified."
  }

  assert {
    condition = length(aws_ssoadmin_permission_set_inline_policy.inline) == 0

    error_message = "No inline policy resource should be created when inline_policy_json is not supplied."
  }

  assert {
    condition = length(aws_ssoadmin_permissions_boundary_attachment.boundary) == 0

    error_message = "No permissions-boundary attachment should be created when permissions_boundary_policy_arn is not supplied."
  }
}

run "attaches_every_supplied_managed_policy" {
  command = apply

  variables {
    permission_set_name = "TestPermissionSet"

    target_account_ids = ["111111111111"]

    principal_id = "g-abc123456"

    aws_managed_policy_arns = [
      "arn:aws:iam::aws:policy/ReadOnlyAccess",
      "arn:aws:iam::aws:policy/SecurityAudit",
    ]
  }

  assert {
    condition = length(aws_ssoadmin_managed_policy_attachment.aws_managed) == 2

    error_message = "Every ARN in aws_managed_policy_arns should get its own attachment resource."
  }
}

run "inline_policy_created_when_supplied" {
  command = apply

  variables {
    permission_set_name = "TestPermissionSet"

    target_account_ids = ["111111111111"]

    principal_id = "g-abc123456"

    inline_policy_json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
  }

  assert {
    condition = length(aws_ssoadmin_permission_set_inline_policy.inline) == 1

    error_message = "Supplying inline_policy_json should create exactly one inline-policy resource."
  }

  assert {
    condition = aws_ssoadmin_permission_set_inline_policy.inline[0].inline_policy == "{\"Version\":\"2012-10-17\",\"Statement\":[]}"

    error_message = "The inline policy resource should carry the exact JSON supplied."
  }
}

run "permissions_boundary_created_when_supplied" {
  command = apply

  variables {
    permission_set_name = "TestPermissionSet"

    target_account_ids = ["111111111111"]

    principal_id = "g-abc123456"

    permissions_boundary_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
  }

  assert {
    condition = length(aws_ssoadmin_permissions_boundary_attachment.boundary) == 1

    error_message = "Supplying permissions_boundary_policy_arn should create exactly one boundary attachment."
  }
}

run "one_account_assignment_per_target_account" {
  command = apply

  variables {
    permission_set_name = "TestPermissionSet"

    target_account_ids = ["111111111111", "222222222222", "333333333333"]

    principal_id = "g-abc123456"
  }

  assert {
    condition = length(aws_ssoadmin_account_assignment.this) == 3

    error_message = "Each entry in target_account_ids should produce exactly one account assignment for the given principal."
  }
}

run "invalid_principal_type_is_rejected" {
  command = plan

  variables {
    permission_set_name = "TestPermissionSet"

    target_account_ids = ["111111111111"]

    principal_id = "g-abc123456"

    principal_type = "ROLE" # not a valid Identity Center principal type
  }

  expect_failures = [
    var.principal_type,
  ]
}

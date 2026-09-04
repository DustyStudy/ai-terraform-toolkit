############################################
# iam-identity-center-permission-set
#
# Creates a standardized IAM Identity Center (SSO) permission set and assigns it to a
# group across one or more target accounts.
############################################

data "aws_ssoadmin_instances" "this" {}

resource "aws_ssoadmin_permission_set" "this" {
  name             = var.permission_set_name
  description      = var.description != "" ? var.description : null
  instance_arn     = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  session_duration = var.session_duration

  tags = var.tags
}

resource "aws_ssoadmin_managed_policy_attachment" "aws_managed" {
  for_each           = toset(var.aws_managed_policy_arns)
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  managed_policy_arn = each.value
  permission_set_arn = aws_ssoadmin_permission_set.this.arn
}

resource "aws_ssoadmin_permission_set_inline_policy" "inline" {
  count              = var.inline_policy_json != null ? 1 : 0
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.this.arn
  inline_policy      = var.inline_policy_json
}

resource "aws_ssoadmin_permissions_boundary_attachment" "boundary" {
  count              = var.permissions_boundary_policy_arn != null ? 1 : 0
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.this.arn

  permissions_boundary {
    managed_policy_arn = var.permissions_boundary_policy_arn
  }
}

resource "aws_ssoadmin_account_assignment" "this" {
  for_each = {
    for pair in setproduct(var.target_account_ids, [var.principal_id]) :
    "${pair[0]}-${pair[1]}" => {
      account_id = pair[0]
      principal  = pair[1]
    }
  }

  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.this.arn

  principal_id   = each.value.principal
  principal_type = var.principal_type

  target_id   = each.value.account_id
  target_type = "AWS_ACCOUNT"
}

# Native Terraform tests. Run with `terraform test` from modules/vpc-baseline/. Fully offline via
# mock_provider — see modules/s3-secure-bucket/tests/main.tftest.hcl for the fuller explanation
# of what these tests do and don't cover.

mock_provider "aws" {
  mock_resource "aws_kms_key" {
    defaults = {
      id  = "mock-kms-key-id"
      arn = "arn:aws:kms:us-east-1:123456789012:key/mock-kms-key-id"
    }
  }
}

run "single_az_creates_matching_resource_counts" {
  command = apply

  variables {
    name_prefix = "test"

    vpc_cidr = "10.0.0.0/16"

    public_subnet_cidrs = {
      "us-east-1a" = "10.0.0.0/24"
    }

    private_subnet_cidrs = {
      "us-east-1a" = "10.0.10.0/24"
    }
  }

  assert {
    condition     = length(aws_subnet.public) == 1
    error_message = "One public_subnet_cidrs entry should produce exactly one public subnet."
  }

  assert {
    condition     = length(aws_subnet.private) == 1
    error_message = "One private_subnet_cidrs entry should produce exactly one private subnet."
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "single_nat_gateway defaults to true, so exactly one NAT gateway should exist."
  }

  assert {
    condition     = contains(keys(aws_nat_gateway.this), "shared")
    error_message = "The single shared NAT gateway should be keyed 'shared', not an AZ name."
  }
}

run "multi_az_with_shared_nat_gateway_still_creates_only_one" {
  command = apply

  variables {
    name_prefix = "test"

    vpc_cidr = "10.0.0.0/16"

    public_subnet_cidrs = {
      "us-east-1a" = "10.0.0.0/24"
      "us-east-1b" = "10.0.1.0/24"
      "us-east-1c" = "10.0.2.0/24"
    }

    private_subnet_cidrs = {
      "us-east-1a" = "10.0.10.0/24"
      "us-east-1b" = "10.0.11.0/24"
      "us-east-1c" = "10.0.12.0/24"
    }

    single_nat_gateway = true
  }

  assert {
    condition     = length(aws_subnet.public) == 3
    error_message = "Three public_subnet_cidrs entries should produce exactly three public subnets."
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "single_nat_gateway = true should produce exactly one NAT gateway regardless of AZ count."
  }

  assert {
    condition     = length(aws_eip.nat) == 1
    error_message = "Only one Elastic IP should be allocated when sharing a single NAT gateway."
  }
}

run "multi_az_with_one_nat_gateway_per_az" {
  command = apply

  variables {
    name_prefix = "test"

    vpc_cidr = "10.0.0.0/16"

    public_subnet_cidrs = {
      "us-east-1a" = "10.0.0.0/24"
      "us-east-1b" = "10.0.1.0/24"
      "us-east-1c" = "10.0.2.0/24"
    }

    private_subnet_cidrs = {
      "us-east-1a" = "10.0.10.0/24"
      "us-east-1b" = "10.0.11.0/24"
      "us-east-1c" = "10.0.12.0/24"
    }

    single_nat_gateway = false
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 3
    error_message = "single_nat_gateway = false should produce one NAT gateway per AZ (3 AZs -> 3 gateways)."
  }

  assert {
    condition     = length(aws_eip.nat) == 3
    error_message = "One Elastic IP should be allocated per NAT gateway when not sharing."
  }

  assert {
    condition     = toset(keys(aws_nat_gateway.this)) == toset(["us-east-1a", "us-east-1b", "us-east-1c"])
    error_message = "Per-AZ NAT gateways should be keyed by AZ name, matching the public subnet AZs."
  }
}

run "flow_logs_are_encrypted_with_the_dedicated_kms_key" {
  command = apply

  variables {
    name_prefix = "test"

    vpc_cidr = "10.0.0.0/16"

    public_subnet_cidrs = {
      "us-east-1a" = "10.0.0.0/24"
    }

    private_subnet_cidrs = {
      "us-east-1a" = "10.0.10.0/24"
    }
  }

  assert {
    condition     = aws_cloudwatch_log_group.flow_logs.kms_key_id == aws_kms_key.flow_logs.arn
    error_message = "The flow-logs log group must be encrypted with this module's own dedicated KMS key, not left unencrypted or on a default key."
  }

  assert {
    condition     = aws_cloudwatch_log_group.flow_logs.retention_in_days == 365
    error_message = "Flow log retention should default to 365 days (FedRAMP Moderate 1-year minimum)."
  }
}

run "default_security_group_gets_a_descriptive_name_tag" {
  command = apply

  variables {
    name_prefix = "test"

    vpc_cidr = "10.0.0.0/16"

    public_subnet_cidrs = {
      "us-east-1a" = "10.0.0.0/24"
    }

    private_subnet_cidrs = {
      "us-east-1a" = "10.0.10.0/24"
    }
  }

  assert {
    condition     = aws_default_security_group.this.tags["Name"] == "test-default-sg-restricted"
    error_message = "The (rule-stripped) default security group should be clearly tagged so nobody mistakes it for an unmanaged default SG."
  }
}

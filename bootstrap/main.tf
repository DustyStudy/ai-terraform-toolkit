############################################
# bootstrap
#
# Creates the S3 bucket + DynamoDB table that every other root config in this repo needs as
# its remote state backend. This config itself necessarily uses local state (you can't store
# state for the thing that stores state) — see README.md for what to do with that local state
# file after applying.
############################################

terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40"
    }
  }

  # Deliberately no backend block — this config bootstraps the backend, so it can't use one
  # itself yet. See README.md for migrating this state into the bucket it creates.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

data "aws_caller_identity" "current" {}

module "state_bucket" {
  source = "../modules/s3-secure-bucket"

  bucket_name = "${var.name_prefix}-terraform-state-${data.aws_caller_identity.current.account_id}"

  tags = var.tags
}

resource "aws_dynamodb_table" "lock" {
  name         = "${var.name_prefix}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  # Protects against `terraform destroy` accidentally taking out the lock table every other
  # root config in this repo depends on.
  deletion_protection_enabled = true

  tags = var.tags
}

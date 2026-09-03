############################################
# landing-zone
#
# Root config for seeding/configuring a single new AWS account: applies the account
# baseline (CloudTrail, Config, GuardDuty, SCPs) and, optionally, a baseline VPC.
#
# Run this once per new account, with the provider authenticated (via OIDC) against
# that account.
############################################

terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40"
    }
  }

  backend "s3" {
    # Fill these in per-environment, e.g. via -backend-config files or CI variables.
    # bucket         = "your-org-terraform-state"
    # key            = "landing-zone/ACCOUNT_ID/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "your-org-terraform-locks"
    # encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

module "account_baseline" {
  source = "../modules/account-baseline"

  name_prefix      = var.name_prefix
  account_id       = var.account_id
  enable_config    = var.enable_config
  enable_guardduty = var.enable_guardduty
  attach_scp_ids   = var.attach_scp_ids

  tags = var.tags
}

module "vpc" {
  count  = var.create_vpc ? 1 : 0
  source = "../modules/vpc-baseline"

  name_prefix          = var.name_prefix
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway

  tags = var.tags
}

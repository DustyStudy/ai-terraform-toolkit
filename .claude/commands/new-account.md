Seed a new AWS account into the org using the `landing-zone` root config.

Ask the user for whatever of the following you don't already know from context:
- Account ID of the new account
- A name prefix (org/team identifier + environment, e.g. `acme-prod`, `acme-dev`)
- Which SCPs (by policy ID) should be attached, if any
- Whether a baseline VPC should be created in this account, and if so: region, VPC CIDR, and
  AZ/subnet CIDR pairs for public and private subnets
- Whether GuardDuty EKS protection is needed (only if the account will run EKS)

Then:
1. Create a new `terraform.tfvars` file for this account (do not overwrite
   `terraform.tfvars.example` — copy it) under `landing-zone/`, or a dedicated
   `landing-zone/accounts/<account_id>.tfvars` file if the user is managing multiple accounts
   from one landing-zone config — ask which pattern they want if unclear.
2. Fill in the tfvars based on the answers above, following the conventions in `CLAUDE.md`.
3. Run `terraform fmt` and `terraform validate` on the landing-zone directory.
4. Show the user a summary of what will be created and ask them to review before you propose a
   `terraform plan`.
5. Do not run `terraform apply`. Remind the user that apply happens via CI after PR review,
   per the workflow in `CLAUDE.md`, unless they explicitly ask for a local apply against a
   sandbox/dev account.
6. Suggest running the `tf-security-reviewer` subagent on the diff before opening a PR.

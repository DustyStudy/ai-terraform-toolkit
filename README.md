# ai-terraform-toolkit

AI-assisted Terraform toolkit for managing multi-account AWS organizations. Reusable,
security-hardened modules plus Claude Code / Gemini integration (context files, custom commands,
and a review subagent) so teams can provision and manage infrastructure safely without needing
deep Terraform expertise.

## Why this exists

Most teams adopting Terraform for a multi-account AWS org face the same problem: a small number
of people know Terraform well, and everyone else either avoids touching infrastructure or copies
existing code without fully understanding it. This repo tries to close that gap two ways:

1. **Opinionated, reusable modules** with security defaults baked in, so correct usage is the
   path of least resistance.
2. **AI assistant integration** (`CLAUDE.md`, `GEMINI.md`, custom commands, a review subagent) so
   someone can describe what they need in plain English and get code that already follows this
   repo's conventions — reviewed by CI and a second AI pass before it's ever applied.

## Repo structure

```
ai-terraform-toolkit/
├── CLAUDE.md                    # Context file read by Claude Code
├── GEMINI.md                    # Context file read by Gemini CLI / Code Assist
├── COMPLIANCE.md                # NIST 800-53 / FedRAMP control mapping
├── modules/
│   ├── account-baseline/        # CloudTrail, Config, GuardDuty, SCP attachment for one account
│   ├── s3-secure-bucket/        # Encrypted, logged, access-blocked S3 bucket
│   ├── iam-identity-center-permission-set/  # Standardized SSO permission sets
│   └── vpc-baseline/            # VPC with public/private subnets, flow logs, no default SG rules
├── landing-zone/                # Root config: seed/configure a new AWS account using the modules
├── .claude/
│   ├── commands/                # Slash commands for common requests
│   └── agents/                  # tf-security-reviewer subagent
├── .checkov.yaml                # Checkov scan configuration
├── .gitleaks.toml                # Gitleaks secret-scanning configuration
├── .tflint.hcl                  # tflint configuration (AWS ruleset)
└── .github/workflows/ci.yml     # fmt, validate, tflint, Checkov, Trivy, Terrascan, Gitleaks
```

## Getting started

1. Fork or clone this repo.
2. Update `CLAUDE.md` / `GEMINI.md` with your org's naming convention, tagging requirements, and
   state backend details (see "Adopting this repo for your own org" in those files).
3. Configure the S3 + DynamoDB remote state backend for your AWS account(s) — see
   `landing-zone/README.md`.
4. Set up OIDC federation between GitHub Actions and your AWS account(s) so CI can run
   `terraform plan` without long-lived credentials.
5. Open the repo in Claude Code or Gemini CLI and try one of the slash commands in
   `.claude/commands/`, e.g. `/new-s3-bucket`.

## Requirements

- Terraform >= 1.7
- AWS provider >= 5.40
- An AWS Organization with IAM Identity Center enabled (for the permission-set module and
  landing zone)
- GitHub Actions (or adapt `ci.yml` to your CI system of choice)

## Security scanning

Every PR, every push to `main`, and a weekly scheduled run all execute:

- `terraform fmt -check` / `terraform validate`
- `tflint` with the AWS ruleset
- **Checkov** — broad IaC policy-as-code checks
- **Trivy** (config scan) — misconfigurations with CVE-aware severity
- **Terrascan** — additional policy-as-code coverage, cross-checking Checkov
- **Gitleaks** — secret scanning across the repo and git history

All scanner results are uploaded as SARIF to GitHub's **Security tab**, so findings are tracked
centrally instead of buried in workflow logs. See `.github/workflows/ci.yml`, `.checkov.yaml`,
`.tflint.hcl`, and `.gitleaks.toml` for configuration, and `COMPLIANCE.md` for how this maps to
NIST 800-53 / FedRAMP control families.

## License

MIT — see `LICENSE`.

## Contributing

Issues and PRs welcome. If you're adding a new module, please include a `README.md` inside the
module directory documenting inputs, outputs, and an example usage block, and make sure it passes
CI before opening the PR.

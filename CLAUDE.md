# CLAUDE.md — ai-terraform-toolkit

This file is read automatically by Claude Code when working in this repo. It exists so anyone
using this toolkit — regardless of Terraform experience — can describe what they need in plain
English and get code that matches this repo's conventions and security baseline.

## What this repo is

A shared Terraform module library + landing-zone tooling for managing a multi-account AWS org,
designed to be driven by AI coding assistants (Claude Code, Gemini) as much as by hand.

## Ground rules (always follow these)

1. **Never write raw AWS resources when a module already covers it.** Check `modules/` first.
   Only drop to raw `resource` blocks when no module exists, and flag that gap to the user.
2. **Never hardcode credentials, account IDs, or secrets.** Use variables, SSM Parameter Store,
   or Secrets Manager references. Auth is always via OIDC — never long-lived access keys.
3. **No `*` in IAM policy `Action` or `Resource` fields** unless explicitly justified in a comment.
4. **All resources must be tagged** with: `Environment`, `Owner`, `ManagedBy = "terraform"`,
   `CostCenter` (ask the user if unknown — don't guess).
5. **State is remote, always.** S3 backend + DynamoDB lock table. Never suggest local state.
6. **Naming convention:** `<org-or-team>-<env>-<resource>-<purpose>`, all lowercase,
   hyphen-separated. Adjust the first segment to whatever identifier the adopting org uses.
7. **Every new resource type should go through a module**, not be written inline in a root config,
   so it's reusable. If asked for something one-off, still suggest a module if it's likely to
   recur.
8. **Never hardcode `arn:aws:...`** for AWS-managed resources. Use
   `data.aws_partition.current.partition` (`"arn:${data.aws_partition.current.partition}:..."`)
   so modules work in both commercial AWS and GovCloud — required for FedRAMP compatibility.
9. **Any new logging/audit resource (CloudTrail, Config, VPC Flow Logs, etc.) must be encrypted
   with a customer-managed KMS key**, not the AWS-managed default, and must have a retention
   period set explicitly — never leave it at the provider default.
10. **Check `COMPLIANCE.md` when adding or changing a module.** If the change affects what
    control family it supports (or stops supporting), update the mapping table in the same PR.

## FedRAMP / compliance posture

This repo is built to support a FedRAMP Moderate baseline (NIST 800-53). Practically, that means:

- Default to the *most* secure option, not the cheapest or simplest, when there's a tradeoff —
  e.g. prefer KMS over SSE-S3, prefer a dedicated NAT gateway per AZ over a single shared one for
  anything beyond dev/sandbox, prefer explicit deny statements over relying on defaults.
- Every new module needs an entry in `COMPLIANCE.md`'s control mapping table — don't skip this
  even for something that feels minor.
- If a request would weaken an existing control (e.g. "just disable versioning on this bucket",
  "turn off log file validation to save cost"), don't do it silently — flag the compliance
  impact explicitly and ask for confirmation.
- CI runs Checkov, Trivy, Terrascan, and Gitleaks on every PR (see `.github/workflows/ci.yml`).
  A red CI run on a security finding is not something to work around with `soft_fail` or a skip
  comment — fix the underlying resource, or escalate to the user if the finding is a genuine
  false positive that needs a documented, reviewed exception.

## Repo structure

- `modules/` — reusable, opinionated modules with security defaults baked in (see each module's
  README for inputs/outputs).
- `landing-zone/` — root config for seeding/configuring a new AWS account into an org
  (SCPs, Identity Center permission sets, CloudTrail, Config, GuardDuty baseline).
- `.claude/commands/` — slash commands for common requests (new account, new S3 bucket, new
  permission set). Prefer pointing the user to these over writing from scratch.
- `.claude/agents/tf-security-reviewer.md` — a separate reviewer persona. After generating or
  editing Terraform, suggest running the review subagent before opening a PR.

## Workflow expectations

1. Understand the request; identify which module(s) apply.
2. Write/modify Terraform using the module(s).
3. Run `terraform fmt` and `terraform validate` locally.
4. Summarize the change and the planned resources in plain English before proposing a PR.
5. PR description must include: what changed, why, and the `terraform plan` output (or a summary
   of it if long).
6. Do not run `terraform apply` directly — apply happens via CI/CD after review, not from a local
   session, unless the user explicitly asks for a local apply against a sandbox/dev account.

## When something doesn't fit the rules above

Say so explicitly rather than silently working around it — e.g. "this needs a wildcard IAM
resource because X; confirm before I proceed" rather than just adding it.

## Adopting this repo for your own org

The rules above are opinionated defaults, not universal law. If your org has different tagging
requirements, naming conventions, or state backend setup, update this file (and `GEMINI.md`) to
match — the whole point is that the AI assistant follows *your* conventions, whatever they are.

## Companion file

`GEMINI.md` mirrors this file for Gemini CLI / Code Assist. If you update one, update the other.

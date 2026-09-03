# GEMINI.md — ai-terraform-toolkit

This file is read automatically by Gemini CLI / Code Assist when working in this repo. It exists so anyone
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

`CLAUDE.md` mirrors this file for Claude Code. If you update one, update the other.

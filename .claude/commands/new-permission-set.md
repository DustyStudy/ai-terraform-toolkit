Create a new IAM Identity Center permission set using the
`iam-identity-center-permission-set` module.

Ask the user for whatever of the following you don't already know from context:
- Permission set name and its purpose (used for the `description`)
- Desired session duration (default to `PT4H` if they don't care)
- Which AWS managed policies should be attached — push back gently if they ask for
  `AdministratorAccess` on something that sounds like it should be scoped down, and suggest a
  narrower alternative (e.g. `ReadOnlyAccess`, `SecurityAudit`, or a specific service policy)
- Whether an inline policy or permissions boundary is needed
- Which account IDs this should be assigned to
- The Identity Center group or user ID (`principal_id`) and whether it's a `GROUP` or `USER` —
  if they don't know the ID, tell them how to look it up: IAM Identity Center console → Groups
  (or `aws identitystore list-groups`)
- Required tags per `CLAUDE.md` conventions

Then:
1. Add a `module "..."` block calling `modules/iam-identity-center-permission-set` in the
   appropriate root config.
2. Run `terraform fmt` and `terraform validate`.
3. Show the user the diff and a plain-English summary, calling out explicitly which accounts
   will have this permission set assigned and what access it grants.
4. Do not run `terraform apply`.
5. Suggest running the `tf-security-reviewer` subagent on the diff before opening a PR — this
   module type (IAM/access) is worth an extra look given the blast radius of a mistake.

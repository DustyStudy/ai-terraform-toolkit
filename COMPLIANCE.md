# Compliance mapping

This toolkit is built to make it easy to reach a **FedRAMP Moderate** baseline posture (NIST
800-53 Rev. 5) when used as intended. This document maps what each module does to the control
families it supports, and calls out what's still a manual/organizational responsibility —
Terraform can't satisfy every control by itself.

**This is guidance, not a compliance attestation.** Actual FedRAMP authorization requires a 3PAO
assessment, a completed SSP, and organizational controls (policy, personnel, physical security)
this repo has no visibility into. Treat this as a technical starting point.

## Control family mapping

| Control Family | Controls (examples) | How this toolkit helps |
|---|---|---|
| **AC** — Access Control | AC-2, AC-3, AC-6 | `iam-identity-center-permission-set` enforces named, scoped permission sets instead of ad hoc IAM users; `account-baseline` supports SCP attachment for preventive guardrails; least-privilege is nudged via `CLAUDE.md`/`GEMINI.md` rules and the `tf-security-reviewer` subagent, which explicitly flags overly broad grants. |
| **AU** — Audit and Accountability | AU-2, AU-6, AU-9, AU-11 | `account-baseline` enables multi-region CloudTrail with log file validation, KMS encryption, and (by default) delivery to CloudWatch Logs for near-real-time review (AU-6). CloudTrail bucket is versioned and public-access-blocked (AU-9, protection of audit info). |
| **SC** — System and Communications Protection | SC-7, SC-8, SC-13, SC-28 | `vpc-baseline` provides network segmentation (public/private subnets) and flow logs; `s3-secure-bucket` denies non-TLS requests (SC-8, transmission confidentiality) and enforces KMS encryption at rest (SC-13, SC-28). |
| **CM** — Configuration Management | CM-2, CM-6, CM-8 | Everything is Terraform — every resource's configuration is version-controlled and reviewable. `account-baseline` enables AWS Config for continuous configuration recording/drift detection (CM-8). CI (`ci.yml`) blocks non-compliant configuration from merging. |
| **IR** — Incident Response | IR-4, IR-5 | GuardDuty (`account-baseline`) provides automated threat detection as an input to incident response; this repo does not build an automated response/remediation pipeline — pair it with something like the `auto-remediate-open-ssh-rdp` pattern if you need that. |
| **RA** — Risk Assessment | RA-5 | The CI pipeline (`ci.yml`) runs Checkov, Trivy, and Terrascan on every PR/push and weekly on a schedule — continuous vulnerability/misconfiguration scanning of infrastructure-as-code, with results surfaced in GitHub's Security tab. |
| **SI** — System and Information Integrity | SI-2, SI-4, SI-7 | GuardDuty malware protection and CloudTrail log file validation; Gitleaks scans for exposed secrets in the repo itself; scheduled weekly scans catch newly disclosed issues even without a code change. |

## What this toolkit does NOT cover

- **Boundary protection at the network edge** (WAF, network firewalls) — not included; add
  alongside `vpc-baseline` if your workload needs it.
- **Data classification and DLP** — organizational process, not infrastructure.
- **Personnel security, physical security, contingency planning (PE, PS, CP families)** —
  entirely organizational; no amount of Terraform satisfies these.
- **POA&M tracking, continuous monitoring reporting (ConMon) to an authorizing official** —
  process/paperwork, not code. This repo can be a *source* of evidence (CI scan results, Config
  compliance status) but doesn't generate the ConMon package itself.
- **FIPS 140-2/3 validated cryptographic modules** — AWS GovCloud and many commercial AWS
  services offer FIPS endpoints; using them is a configuration choice (endpoint selection) left
  to the deploying org, not something this toolkit enforces.

## GovCloud vs. commercial AWS

Modules use `data.aws_partition.current.partition` rather than hardcoded `arn:aws:...` strings
where AWS-managed resource ARNs are referenced, so they work in both the `aws` (commercial) and
`aws-us-gov` (GovCloud) partitions without modification. If you add new AWS-managed policy or
service ARNs to a module, follow the same pattern — hardcoding `arn:aws:` will silently break in
GovCloud.

## Scanning stack (see `.github/workflows/ci.yml`)

| Tool | What it catches |
|---|---|
| `terraform validate` / `fmt` | Syntax errors, drift from canonical formatting |
| `tflint` (+ AWS ruleset) | AWS provider-specific correctness issues, deprecated syntax |
| Checkov | Broad IaC security/compliance policy checks (700+ built-in policies) |
| Trivy (config scan) | Misconfigurations, with CVE-aware severity scoring |
| Terrascan | Additional policy-as-code coverage, useful for cross-checking Checkov |
| Gitleaks | Hardcoded secrets/credentials committed to the repo, including git history |

Running multiple scanners is intentional redundancy, not waste — different tools catch different
things and none has perfect coverage. All results are uploaded as SARIF to GitHub's Security tab
so findings are tracked in one place rather than buried in workflow logs.

## Keeping this document current

If you add a module or change what an existing one does, update the control mapping table above
in the same PR. A compliance mapping that's out of date is worse than none — it creates false
confidence.

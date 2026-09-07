# Security Policy

## Reporting a vulnerability

If you find a security issue in one of this repo's modules or workflows — a misconfiguration
that undermines the security baseline these modules are meant to enforce, a flaw in the CI
security-scanning setup itself, or anything that could let a consumer of these modules end up
with an insecure result despite following the documented usage — please report it privately
rather than opening a public issue.

Use GitHub's private vulnerability reporting: go to the **Security** tab → **Advisories** →
**Report a vulnerability**. This opens a private channel between you and the maintainer, separate
from public issues/PRs, and lets us coordinate a fix (and, if warranted, a GitHub Security
Advisory and a patched release) before any details go public.

Please include:
- Which module/workflow is affected, and the version/commit you tested against
- Steps to reproduce, or a minimal Terraform config that demonstrates the issue
- The impact you'd expect for someone using the module as documented

## Scope

This covers the Terraform modules under `modules/`, the root configs under `landing-zone/` and
`bootstrap/`, and the CI/CD workflows under `.github/workflows/`. It does not cover vulnerabilities
in upstream dependencies themselves (the AWS provider, GitHub Actions, or scanning tools like
Checkov/Trivy/Terrascan/Gitleaks) — please report those to their respective projects. If a
vulnerability in an upstream dependency affects how this repo uses it (e.g. a provider bug that
defeats one of these modules' security defaults), that's in scope here too.

## Supported versions

Only the latest tagged release is actively supported. If you're running an older tag and a fix
lands, please upgrade rather than requesting a backport.

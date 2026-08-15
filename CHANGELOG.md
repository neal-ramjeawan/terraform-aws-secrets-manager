# Changelog

All notable changes to this module are documented here. Format loosely
follows [Keep a Changelog](https://keepachangelog.com/), versions follow
[SemVer](https://semver.org/).

## [0.1.0] - 2026-08-16

### Added
- Initial release: Secrets Manager secret with optional initial value,
  and tag-driven rotation (`tags["rotation"] = "true"`) that composes
  [`terraform-aws-lambda`](https://github.com/<you>/terraform-aws-lambda)
  `v0.1.0` to build and attach a generic rotation handler
- Mocked `terraform test` suite — AWS provider mocked, no credentials or
  cost; `terraform init` does need network access to pull
  `terraform-aws-lambda`
- GitHub Actions CI: fmt/validate/test, `tflint` (AWS ruleset), and Trivy
  IaC scanning (tfsec's successor — tfsec is deprecated)
- `terraform-docs` wired into CI — the Inputs/Outputs reference in this
  README regenerates automatically on every PR
- Tag-triggered GitHub Releases, with notes pulled from this file
- `SECURITY.md` and issue templates

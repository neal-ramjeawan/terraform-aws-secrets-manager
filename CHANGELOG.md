# Changelog

All notable changes to this module are documented here. Format loosely
follows [Keep a Changelog](https://keepachangelog.com/), versions follow
[SemVer](https://semver.org/).

## [0.1.1] - 2026-08-16

### Fixed
- `terraform init` failed in real CI: `module "rotation_lambda"`'s source
  still had the literal `<you>` placeholder instead of a real GitHub
  username, so the `terraform-aws-lambda` dependency couldn't be cloned
  at all — `remote: Repository not found`. Replaced with the actual repo
  owner throughout (this file, README, everywhere `<you>` appeared).
- `terraform init` then failed a second time, same line, different cause:
  the ref pointed at `v0.1.0`, but that tag was never actually published
  on `terraform-aws-lambda` — it got superseded by fixes before i
  pushed it. Since `v0.1.1` is what will actually exist as that repo's
  first real tag, repointed the ref there.
- `terraform test` then failed a third time: with rotation enabled, a
  `count` inside the composed `terraform-aws-lambda` module depends on a
  value that flows from a mocked data source across the module boundary
  — not knowable at plan-only, even with `mock_data` supplying a default.
  Switched the two rotation-enabling test runs from `command = plan` to
  `command = apply` (still fully mocked, still free) so the value
  actually resolves.

## [0.1.0] - 2026-08-16

### Added
- Initial release: Secrets Manager secret with optional initial value,
  and tag-driven rotation (`tags["rotation"] = "true"`) that composes
  [`terraform-aws-lambda`](https://github.com/neal-ramjeawan/terraform-aws-lambda)
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
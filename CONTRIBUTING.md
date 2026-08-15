# Contributing

## Making a change

1. Branch, make the change, update `tests/secrets-manager.tftest.hcl` if
   behavior changed.
2. Run `terraform fmt`, `terraform validate`, and `terraform test` locally
   — CI runs the same three checks and will block the PR otherwise.
   `terraform init` needs real network access here (it pulls
   `terraform-aws-lambda` from GitHub), even though the AWS provider
   itself stays mocked.
3. Update `README.md` if variables, outputs, or behavior changed.
4. Update `CHANGELOG.md` in the same PR as the change, not as a
   follow-up.

## Bumping the terraform-aws-lambda dependency

This module composes `terraform-aws-lambda` via a pinned `ref` in
`main.tf` (`module "rotation_lambda"`). To pick up a new release:

1. Update the `ref` in `main.tf` to the new tag.
2. Re-run `terraform test` — the mocked plan will catch anything that
   broke.
3. Note the bump in `CHANGELOG.md` even though no variables/outputs of
   *this* module changed — the dependency version is part of what
   changed.

## Versioning

Plain semver tags: `v0.1.0`, `v0.2.0`, etc. Breaking variable/output
changes bump the major version, additive changes bump minor, fixes bump
patch.

## Pull requests

CI (`fmt`, `validate`, `test`, `tflint`, Trivy) must pass. `terraform-docs` regenerates the README automatically — no need to run it yourself before pushing. If the PR changes this module's
variables or outputs, say so explicitly in the description.

# terraform-aws-secrets-manager

Creates a secret in AWS Secrets Manager. If the secret is tagged
`rotation = "true"`, the module automatically composes the
[`terraform-aws-lambda`](https://github.com/neal-ramjeawan/terraform-aws-lambda)
module to build and attach a rotation Lambda — no separate rotation
variable to remember to set. Remove the tag (or set it to anything else)
and rotation goes away on the next apply.

```hcl
module "api_key" {
  source = "git::https://github.com/neal-ramjeawan/terraform-aws-secrets-manager.git?ref=v0.1.0"

  secret_name = "myapp-api-key"

  tags = {
    Environment = "prod"
    rotation    = "true"   # <- this one tag is what turns rotation on
  }
}
```

## What "rotation = true" actually wires up

1. Zips [`lambda/rotation_handler.py`](lambda/rotation_handler.py) via the
   `archive` provider (no external build step — `terraform plan` does it).
2. Builds an IAM policy scoped to `secretsmanager:GetSecretValue` /
   `PutSecretValue` / `UpdateSecretVersionStage` / `DescribeSecret` on
   *this specific secret's ARN* (plus `GetRandomPassword`, which AWS
   doesn't support resource-level scoping for at all).
3. Calls `module "rotation_lambda" { source = "git::https://github.com/neal-ramjeawan/terraform-aws-lambda.git?ref=v0.1.1" ... }`,
   passing that policy in via `additional_inline_policy_json` and granting
   Secrets Manager invoke access via `allowed_triggers` — reusing that
   module's generic mechanism rather than a bespoke permission resource.
   This is a real cross-repo dependency: bumping `terraform-aws-lambda`
   doesn't affect this module until the `ref` here is deliberately updated
   to the new tag.
4. Creates `aws_secretsmanager_secret_rotation`, scheduled every
   `rotation_days` (default 30).

## What the generic rotation handler does — and doesn't do

The bundled handler implements Secrets Manager's four-step rotation
protocol (`createSecret` / `setSecret` / `testSecret` / `finishSecret`),
generating the new value with Secrets Manager's own `GetRandomPassword`
API. It does **not** push that value anywhere else.

That's the right fit for a standalone secret — an API key, a token,
anything where Secrets Manager is the only place the value lives. It's
**not** the right fit for something like a database password, where a
real system also needs the new credential set. For that, fork
`rotation_handler.py` and implement `set_secret()` (and usually
`test_secret()`) against that system — AWS's own RDS/database rotation
templates are the reference for what that looks like. This module
intentionally ships the generic, no-external-dependency case rather than
guessing at your database engine.

## Reference

Auto-generated from `variables.tf`/`outputs.tf` on every PR — see `.github/workflows/docs.yml`. Don't hand-edit between the markers, it'll just get overwritten.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | ~> 2.4 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | ~> 2.4 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_rotation_lambda"></a> [rotation\_lambda](#module\_rotation\_lambda) | git::https://github.com/neal-ramjeawan/terraform-aws-lambda.git | v0.1.0 |

## Resources

| Name | Type |
|------|------|
| [aws_secretsmanager_secret.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_rotation.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_rotation) | resource |
| [aws_secretsmanager_secret_version.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [archive_file.rotation_lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_iam_policy_document.rotation_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_description"></a> [description](#input\_description) | Description of the secret. | `string` | `""` | no |
| <a name="input_initial_secret_string"></a> [initial\_secret\_string](#input\_initial\_secret\_string) | Optional initial value for the secret. Leave null to set the value out-of-band (console/CLI/CI) after creation, keeping it out of Terraform state and plan output. | `string` | `null` | no |
| <a name="input_recovery_window_in_days"></a> [recovery\_window\_in\_days](#input\_recovery\_window\_in\_days) | Days before a deleted secret is actually removed. 0 deletes immediately with no recovery window — convenient for demo/teardown, riskier for anything real. | `number` | `7` | no |
| <a name="input_rotation_days"></a> [rotation\_days](#input\_rotation\_days) | Rotation interval in days. Only used when rotation is enabled via the rotation=true tag. | `number` | `30` | no |
| <a name="input_secret_name"></a> [secret\_name](#input\_secret\_name) | Name of the secret. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the secret. Set tags["rotation"] = "true" to automatically attach a rotation Lambda — no other variable needed. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_rotation_enabled"></a> [rotation\_enabled](#output\_rotation\_enabled) | Whether rotation was enabled (tags["rotation"] == "true"). |
| <a name="output_rotation_lambda_arn"></a> [rotation\_lambda\_arn](#output\_rotation\_lambda\_arn) | ARN of the rotation Lambda, if rotation is enabled. |
| <a name="output_secret_arn"></a> [secret\_arn](#output\_secret\_arn) | ARN of the secret. |
| <a name="output_secret_name"></a> [secret\_name](#output\_secret\_name) | Name of the secret. |
<!-- END_TF_DOCS -->

## Notes

- `initial_secret_string` is optional and `sensitive = true`. Leaving it
  `null` (the default) means the secret starts empty and you set the real
  value out-of-band — keeps it out of Terraform state and plan output
  entirely. Only set it if you're comfortable with the value living in
  state.
- `recovery_window_in_days = 0` deletes a secret immediately with no
  recovery window, if you want fast teardown for a demo — the default (7)
  is safer and matches AWS's own default.
- Consumers of this module need `hashicorp/archive` in their own
  `required_providers` too — provider requirements from a child module
  propagate up, so `terraform init` will tell you if it's missing.

## Testing

```bash
terraform test
```

Runs `tests/secrets-manager.tftest.hcl` against a mocked AWS provider — no
credentials, no real resources, no cost. The `archive` provider isn't
mocked (it just zips the real handler file on disk, which is free and
harmless). Requires Terraform 1.7.0+.

One thing that changed by splitting this into its own repo: `terraform
init` now needs real network access to pull `terraform-aws-lambda` from
GitHub (it's a `git::` source, not a local relative path anymore). Still
completely free, just no longer fully offline the way a same-repo
composition would be — worth knowing if you're ever running this somewhere
genuinely airgapped.
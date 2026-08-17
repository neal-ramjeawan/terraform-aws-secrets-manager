locals {
  rotation_enabled = try(var.tags["rotation"], "false") == "true"
}

resource "aws_secretsmanager_secret" "this" {
  name                    = var.secret_name
  description             = var.description
  recovery_window_in_days = var.recovery_window_in_days
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "this" {
  count = var.initial_secret_string != null ? 1 : 0

  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = var.initial_secret_string
}

# ---------------------------------------------------------------------------
# Rotation — only created when tags["rotation"] = "true". Composes the
# lambda-function module rather than defining aws_lambda_function directly.
# ---------------------------------------------------------------------------

data "archive_file" "rotation_lambda" {
  count = local.rotation_enabled ? 1 : 0

  type        = "zip"
  source_file = "${path.module}/lambda/rotation_handler.py"
  output_path = "${path.module}/lambda/rotation_handler.zip"
}

# Broad-but-scoped: read/write access to this one secret's value, plus
# GetRandomPassword, which doesn't support resource-level scoping at all.
data "aws_iam_policy_document" "rotation_permissions" {
  count = local.rotation_enabled ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
      "secretsmanager:UpdateSecretVersionStage",
    ]
    resources = [aws_secretsmanager_secret.this.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetRandomPassword"]
    resources = ["*"]
  }
}

module "rotation_lambda" {
  count  = local.rotation_enabled ? 1 : 0
  source = "git::https://github.com/neal-ramjeawan/terraform-aws-lambda.git?ref=v0.1.2"

  function_name = "${var.secret_name}-rotation"
  description   = "Rotates ${var.secret_name} — created by the secrets-manager module"
  runtime       = "python3.12"
  handler       = "rotation_handler.lambda_handler"
  timeout       = 30

  filename         = data.archive_file.rotation_lambda[0].output_path
  source_code_hash = data.archive_file.rotation_lambda[0].output_base64sha256

  additional_inline_policy_json   = data.aws_iam_policy_document.rotation_permissions[0].json
  attach_additional_inline_policy = true # this module block only runs when rotation is on — always true here, so no inference needed

  allowed_triggers = {
    secretsmanager = {
      principal  = "secretsmanager.amazonaws.com"
      source_arn = aws_secretsmanager_secret.this.arn
    }
  }

  tags = var.tags
}

resource "aws_secretsmanager_secret_rotation" "this" {
  count = local.rotation_enabled ? 1 : 0

  secret_id           = aws_secretsmanager_secret.this.id
  rotation_lambda_arn = module.rotation_lambda[0].function_arn

  rotation_rules {
    automatically_after_days = var.rotation_days
  }

  depends_on = [module.rotation_lambda]
}

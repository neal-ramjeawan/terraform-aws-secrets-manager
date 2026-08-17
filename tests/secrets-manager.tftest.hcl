# Fully mocks the AWS provider — no credentials, no real API calls, no cost.
# The archive provider isn't mocked; it just zips the real rotation_handler.py
# on disk, which is harmless and free.
# Run with: terraform test (from the repo root)
#
# Without the mock_data override below, aws_iam_policy_document's own
# computed `.json` output gets faked out too (mock_provider mocks the whole
# provider, not just resources that hit a real API) — and the fake string
# isn't valid JSON, which breaks rotation_permissions here and, when
# rotation is enabled, the composed terraform-aws-lambda module's own
# assume-role policy too (same mocked provider instance, same bug).

mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect    = "Allow"
            Action    = "sts:AssumeRole"
            Principal = { Service = "secretsmanager.amazonaws.com" }
          }
        ]
      })
    }
  }

  # The composed terraform-aws-lambda module passes the IAM role ARN
  # directly to aws_lambda_function.role. Terraform's default mock value
  # for this attribute is not a valid ARN, so provide a realistic mock.
  mock_resource "aws_iam_role" {
    defaults = {
      arn  = "arn:aws:iam::123456789012:role/test-role"
      name = "test-role"
    }
  }

  # The secret ARN is passed to the Lambda module as source_arn for the
  # Secrets Manager trigger and is also used in the IAM policy document.
  # Terraform's default mock value is not a valid ARN, so provide a
  # realistic Secrets Manager ARN.
  mock_resource "aws_secretsmanager_secret" {
    defaults = {
      arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test-secret"
    }
  }
}

variables {
  secret_name = "test-secret"
}

run "creates_secret_without_rotation_by_default" {
  command = plan

  assert {
    condition     = aws_secretsmanager_secret.this.name == "test-secret"
    error_message = "Secret name should match secret_name"
  }

  assert {
    condition     = length(aws_secretsmanager_secret_rotation.this) == 0
    error_message = "No rotation should be configured without the rotation=true tag"
  }

  assert {
    condition     = length(module.rotation_lambda) == 0
    error_message = "No rotation lambda should be created without the rotation=true tag"
  }
}

run "no_initial_version_by_default" {
  command = plan

  assert {
    condition     = length(aws_secretsmanager_secret_version.this) == 0
    error_message = "No initial version should be created unless initial_secret_string is set"
  }
}

run "enables_rotation_when_tagged" {
  # plan-only can't resolve this: the count inside the composed
  # terraform-aws-lambda module (aws_iam_role_policy.inline) depends on
  # additional_inline_policy_json, which flows from a mocked data source
  # across the module boundary — Terraform can't know that value without
  # actually completing an apply, even a fully mocked one.
  command = apply

  variables {
    tags = {
      rotation = "true"
    }
  }

  assert {
    condition     = length(aws_secretsmanager_secret_rotation.this) == 1
    error_message = "Expected rotation to be configured when tags[\"rotation\"] = \"true\""
  }

  assert {
    condition     = length(module.rotation_lambda) == 1
    error_message = "Expected the rotation lambda module to be instantiated"
  }
}

run "no_rotation_for_unrelated_tags" {
  command = plan

  variables {
    tags = {
      environment = "prod"
    }
  }

  assert {
    condition     = length(aws_secretsmanager_secret_rotation.this) == 0
    error_message = "Unrelated tags should not trigger rotation"
  }
}

run "rotation_days_flows_into_rotation_rules" {
  # Same reason as enables_rotation_when_tagged above — rotation on means
  # the cross-module count can't resolve at plan-only.
  command = apply

  variables {
    tags          = { rotation = "true" }
    rotation_days = 45
  }

  assert {
    condition     = aws_secretsmanager_secret_rotation.this[0].rotation_rules[0].automatically_after_days == 45
    error_message = "rotation_days should control the rotation schedule"
  }
}
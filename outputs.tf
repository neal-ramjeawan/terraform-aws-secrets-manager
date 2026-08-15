output "secret_arn" {
  description = "ARN of the secret."
  value       = aws_secretsmanager_secret.this.arn
}

output "secret_name" {
  description = "Name of the secret."
  value       = aws_secretsmanager_secret.this.name
}

output "rotation_enabled" {
  description = "Whether rotation was enabled (tags[\"rotation\"] == \"true\")."
  value       = local.rotation_enabled
}

output "rotation_lambda_arn" {
  description = "ARN of the rotation Lambda, if rotation is enabled."
  value       = local.rotation_enabled ? module.rotation_lambda[0].function_arn : null
}

variable "secret_name" {
  description = "Name of the secret."
  type        = string
}

variable "description" {
  description = "Description of the secret."
  type        = string
  default     = ""
}

variable "initial_secret_string" {
  description = "Optional initial value for the secret. Leave null to set the value out-of-band (console/CLI/CI) after creation, keeping it out of Terraform state and plan output."
  type        = string
  default     = null
  sensitive   = true
}

variable "recovery_window_in_days" {
  description = "Days before a deleted secret is actually removed. 0 deletes immediately with no recovery window — convenient for demo/teardown, riskier for anything real."
  type        = number
  default     = 7
}

variable "rotation_days" {
  description = "Rotation interval in days. Only used when rotation is enabled via the rotation=true tag."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags applied to the secret. Set tags[\"rotation\"] = \"true\" to automatically attach a rotation Lambda — no other variable needed."
  type        = map(string)
  default     = {}
}

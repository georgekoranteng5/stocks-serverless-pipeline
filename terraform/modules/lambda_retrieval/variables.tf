variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev)"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Movers DynamoDB table name (injected as DYNAMODB_TABLE_NAME)"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "Movers DynamoDB table ARN (scopes read-only IAM)"
  type        = string
}

variable "lambda_timeout_seconds" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 10
}

variable "lambda_memory_mb" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 128
}

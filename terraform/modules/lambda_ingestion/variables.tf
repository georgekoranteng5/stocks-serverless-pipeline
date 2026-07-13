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
  description = "Movers DynamoDB table ARN (scopes PutItem IAM)"
  type        = string
}

variable "stock_api_key" {
  description = "Massive.com (or Finnhub) API key; injected as STOCK_API_KEY"
  type        = string
  sensitive   = true
}

variable "lambda_timeout_seconds" {
  description = "Lambda timeout — enough for sequential watchlist calls + retries"
  type        = number
  default     = 30
}

variable "lambda_memory_mb" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 256
}

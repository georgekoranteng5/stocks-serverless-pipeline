variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev)"
  type        = string
}

variable "lambda_function_name" {
  description = "Ingestion Lambda function name (for aws_lambda_permission)"
  type        = string
}

variable "lambda_function_arn" {
  description = "Ingestion Lambda ARN (EventBridge target)"
  type        = string
}

variable "schedule_expression" {
  description = "EventBridge schedule expression (rate() or cron())"
  type        = string
  # Once every 24h at 13:00 UTC — project default daily cadence.
  # Massive Basic is end-of-day delayed; the ingestion handler already resolves the
  # latest completed trading session, so this is a reliable hands-off trigger time.
  # Override via terraform.tfvars for a different wall-clock (e.g. after 16:00 ET:
  # cron(0 21 * * ? *)).
  default = "cron(0 13 * * ? *)"
}

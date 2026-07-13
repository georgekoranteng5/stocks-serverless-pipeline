variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used as a prefix for resources and tags"
  type        = string
  default     = "stocks_pipeline"
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "stock_api_key" {
  description = "API key for Massive.com (or Finnhub fallback); injected into Lambda env — never commit real values"
  type        = string
  sensitive   = true
}

variable "ingestion_schedule_expression" {
  description = "EventBridge schedule for the ingestion Lambda (rate() or cron())"
  type        = string
  default     = "cron(0 13 * * ? *)"
}

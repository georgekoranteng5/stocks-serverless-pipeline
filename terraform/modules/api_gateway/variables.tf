variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev)"
  type        = string
}

variable "lambda_function_name" {
  description = "Retrieval Lambda function name (for aws_lambda_permission)"
  type        = string
}

variable "lambda_function_arn" {
  description = "Retrieval Lambda function ARN (HTTP API AWS_PROXY integration URI)"
  type        = string
}

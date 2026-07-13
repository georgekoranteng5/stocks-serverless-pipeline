output "lambda_function_arn" {
  description = "Ingestion Lambda function ARN (for EventBridge target in a later step)"
  value       = aws_lambda_function.ingestion.arn
}

output "lambda_function_name" {
  description = "Ingestion Lambda function name (for aws lambda invoke)"
  value       = aws_lambda_function.ingestion.function_name
}

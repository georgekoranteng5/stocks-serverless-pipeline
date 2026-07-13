output "lambda_function_arn" {
  description = "Retrieval Lambda function ARN"
  value       = aws_lambda_function.retrieval.arn
}

output "lambda_function_name" {
  description = "Retrieval Lambda function name"
  value       = aws_lambda_function.retrieval.function_name
}

output "lambda_invoke_arn" {
  description = "Invoke ARN for API Gateway Lambda proxy integration"
  value       = aws_lambda_function.retrieval.invoke_arn
}

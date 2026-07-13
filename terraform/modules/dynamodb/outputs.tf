output "table_name" {
  description = "DynamoDB table name (for Lambda env / SDK calls)"
  value       = aws_dynamodb_table.movers.name
}

output "table_arn" {
  description = "DynamoDB table ARN (for least-privilege IAM policies)"
  value       = aws_dynamodb_table.movers.arn
}

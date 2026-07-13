output "dynamodb_table_name" {
  description = "Name of the movers DynamoDB table (sanity-check after apply; useful for local scripts)"
  value       = module.dynamodb.table_name
}

output "ingestion_lambda_function_name" {
  description = "Ingestion Lambda name for aws lambda invoke"
  value       = module.lambda_ingestion.lambda_function_name
}

output "eventbridge_rule_name" {
  description = "Daily ingestion EventBridge rule name"
  value       = module.eventbridge.schedule_rule_name
}

output "api_gateway_invoke_url" {
  description = "HTTP API base invoke URL"
  value       = module.api_gateway.invoke_url
}

output "movers_url" {
  description = "Full URL for GET /movers"
  value       = module.api_gateway.movers_url
}

output "frontend_bucket_name" {
  description = "S3 bucket name for the static frontend"
  value       = module.s3_frontend.bucket_name
}

output "s3_website_url" {
  description = "S3 static website URL"
  value       = module.s3_frontend.website_url
}

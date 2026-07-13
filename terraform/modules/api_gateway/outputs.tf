output "invoke_url" {
  description = "HTTP API base URL (append /movers for the movers endpoint)"
  value       = aws_apigatewayv2_api.movers.api_endpoint
}

output "movers_url" {
  description = "Full URL for GET /movers"
  value       = "${aws_apigatewayv2_api.movers.api_endpoint}/movers"
}

output "api_id" {
  description = "HTTP API ID"
  value       = aws_apigatewayv2_api.movers.id
}

locals {
  api_name = "${var.project_name}-${var.environment}-movers-api"
}

resource "aws_apigatewayv2_api" "movers" {
  name          = local.api_name
  protocol_type = "HTTP"
  description   = "Public GET /movers API for top-mover history"

  # CORS on the API (belt-and-suspenders with Lambda response headers).
  cors_configuration {
    allow_credentials = false
    allow_headers     = ["content-type"]
    allow_methods     = ["GET", "OPTIONS"]
    allow_origins     = ["*"]
    max_age           = 300
  }
}

resource "aws_apigatewayv2_integration" "retrieval" {
  api_id                 = aws_apigatewayv2_api.movers.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.lambda_function_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_movers" {
  api_id    = aws_apigatewayv2_api.movers.id
  route_key = "GET /movers"
  target    = "integrations/${aws_apigatewayv2_integration.retrieval.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.movers.id
  name        = "$default"
  auto_deploy = true
}

# Scoped to this API's execution ARN — not a wildcard principal alone.
resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowExecutionFromHttpApiMovers"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.movers.execution_arn}/*/*"
}

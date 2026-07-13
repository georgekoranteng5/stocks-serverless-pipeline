locals {
  rule_name = "${var.project_name}-${var.environment}-daily-ingestion"
}

resource "aws_cloudwatch_event_rule" "daily_ingestion" {
  name                = local.rule_name
  description         = "Invoke ingestion Lambda once per day to record the watchlist top mover"
  schedule_expression = var.schedule_expression
  state               = "ENABLED"
}

resource "aws_cloudwatch_event_target" "ingestion_lambda" {
  rule      = aws_cloudwatch_event_rule.daily_ingestion.name
  target_id = "ingestion-lambda"
  arn       = var.lambda_function_arn
}

# Least privilege: only *this* rule may invoke the function — not any EventBridge rule.
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridgeDailyIngestion"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_ingestion.arn
}

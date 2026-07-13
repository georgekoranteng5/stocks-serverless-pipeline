output "schedule_rule_arn" {
  description = "EventBridge schedule rule ARN"
  value       = aws_cloudwatch_event_rule.daily_ingestion.arn
}

output "schedule_rule_name" {
  description = "EventBridge schedule rule name"
  value       = aws_cloudwatch_event_rule.daily_ingestion.name
}

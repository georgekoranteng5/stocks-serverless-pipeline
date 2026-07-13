# Single table: one item per day for the watchlist's top absolute % mover.
# Non-key attributes (ticker, percent_change, closing_price, created_at) are
# written by the ingestion Lambda — DynamoDB is schemaless beyond the key schema.
# Tags come from the root AWS provider default_tags (Project, Environment, ManagedBy).

resource "aws_dynamodb_table" "movers" {
  name         = "${var.project_name}-${var.environment}-movers"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "date"

  attribute {
    name = "date"
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
}

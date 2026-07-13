# Root module: wires child modules together.
# Logic lives in modules/; fill each in later steps. Pass only the inputs each module needs.

# DynamoDB: one top-mover item per day (PK date; PAY_PER_REQUEST)
module "dynamodb" {
  source = "./modules/dynamodb"

  project_name = var.project_name
  environment  = var.environment
  # enable_point_in_time_recovery defaults to false in the module
}

# Ingestion Lambda: writer (stock API → PutItem). Separate least-privilege role.
module "lambda_ingestion" {
  source = "./modules/lambda_ingestion"

  project_name        = var.project_name
  environment         = var.environment
  stock_api_key       = var.stock_api_key
  dynamodb_table_name = module.dynamodb.table_name
  dynamodb_table_arn  = module.dynamodb.table_arn
}

# Retrieval Lambda: API-triggered reader (GetItem/BatchGetItem/Query only).
module "lambda_retrieval" {
  source = "./modules/lambda_retrieval"

  project_name        = var.project_name
  environment         = var.environment
  dynamodb_table_name = module.dynamodb.table_name
  dynamodb_table_arn  = module.dynamodb.table_arn
}

# EventBridge: once-per-day schedule → ingestion Lambda (permission scoped to this rule)
module "eventbridge" {
  source = "./modules/eventbridge"

  project_name         = var.project_name
  environment          = var.environment
  lambda_function_name = module.lambda_ingestion.lambda_function_name
  lambda_function_arn  = module.lambda_ingestion.lambda_function_arn
  schedule_expression  = var.ingestion_schedule_expression
}

# HTTP API: public GET /movers → retrieval Lambda (no auth — frontend will call directly)
module "api_gateway" {
  source = "./modules/api_gateway"

  project_name         = var.project_name
  environment          = var.environment
  lambda_function_name = module.lambda_retrieval.lambda_function_name
  lambda_function_arn  = module.lambda_retrieval.lambda_function_arn
}

# S3 static website for the movers table UI (public GetObject only)
module "s3_frontend" {
  source = "./modules/s3_frontend"

  project_name = var.project_name
  environment  = var.environment
}

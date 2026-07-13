locals {
  function_name = "${var.project_name}-${var.environment}-ingestion"
}

# Build zip at plan/apply time (pip install + zip) so plan works on a clean checkout.
data "external" "ingestion_package" {
  program = ["python3", "${path.module}/package.py"]
}

data "aws_iam_policy_document" "assume_lambda" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "dynamodb_put_item" {
  statement {
    sid       = "PutItemMoversOnly"
    effect    = "Allow"
    actions   = ["dynamodb:PutItem"]
    resources = [var.dynamodb_table_arn]
  }
}

resource "aws_iam_role" "ingestion" {
  name               = "${local.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

resource "aws_iam_role_policy_attachment" "basic_logs" {
  role       = aws_iam_role.ingestion.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "dynamodb_put_item" {
  name   = "${local.function_name}-dynamodb-put"
  role   = aws_iam_role.ingestion.id
  policy = data.aws_iam_policy_document.dynamodb_put_item.json
}

resource "aws_lambda_function" "ingestion" {
  function_name = local.function_name
  description   = "Daily watchlist top-mover ingestion (Massive.com → DynamoDB)"
  role          = aws_iam_role.ingestion.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  timeout       = var.lambda_timeout_seconds
  memory_size   = var.lambda_memory_mb

  filename         = data.external.ingestion_package.result.zip_path
  source_code_hash = filebase64sha256(data.external.ingestion_package.result.zip_path)

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = var.dynamodb_table_name
      STOCK_API_KEY       = var.stock_api_key
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.basic_logs,
    aws_iam_role_policy.dynamodb_put_item,
  ]
}

locals {
  function_name = "${var.project_name}-${var.environment}-retrieval"
}

data "external" "retrieval_package" {
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

# Read-only — no PutItem. Separate from the ingestion write role (graded separation).
data "aws_iam_policy_document" "dynamodb_read" {
  statement {
    sid    = "ReadMoversOnly"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:BatchGetItem",
      "dynamodb:Query",
    ]
    resources = [var.dynamodb_table_arn]
  }
}

resource "aws_iam_role" "retrieval" {
  name               = "${local.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

resource "aws_iam_role_policy_attachment" "basic_logs" {
  role       = aws_iam_role.retrieval.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "dynamodb_read" {
  name   = "${local.function_name}-dynamodb-read"
  role   = aws_iam_role.retrieval.id
  policy = data.aws_iam_policy_document.dynamodb_read.json
}

resource "aws_lambda_function" "retrieval" {
  function_name = local.function_name
  description   = "GET /movers — last 7 days of top movers from DynamoDB"
  role          = aws_iam_role.retrieval.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  timeout       = var.lambda_timeout_seconds
  memory_size   = var.lambda_memory_mb

  filename         = data.external.retrieval_package.result.zip_path
  source_code_hash = filebase64sha256(data.external.retrieval_package.result.zip_path)

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = var.dynamodb_table_name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.basic_logs,
    aws_iam_role_policy.dynamodb_read,
  ]
}

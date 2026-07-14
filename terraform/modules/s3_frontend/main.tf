data "aws_caller_identity" "current" {}

locals {
  # S3 bucket names cannot contain underscores — normalize the project prefix.
  # Account ID suffix keeps the name globally unique without a random provider.
  name_prefix = replace("${var.project_name}-${var.environment}", "_", "-")
  bucket_name = "${local.name_prefix}-frontend-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "frontend" {
  bucket = local.bucket_name
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Intentional public website hosting: allow a public bucket policy.
# block_public_acls stays on — we use a GetObject-only bucket policy, not ACLs.
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Public read is intentional for static website hosting.
# Scoped to s3:GetObject on this bucket's objects only — no List/Put/Delete.
data "aws_iam_policy_document" "public_read" {
  statement {
    sid    = "PublicReadGetObjectOnly"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.public_read.json

  depends_on = [
    aws_s3_bucket_public_access_block.frontend,
    aws_s3_bucket_ownership_controls.frontend,
  ]
}

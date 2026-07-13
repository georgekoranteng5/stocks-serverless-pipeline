output "bucket_name" {
  description = "Frontend S3 bucket name (for aws s3 sync)"
  value       = aws_s3_bucket.frontend.bucket
}

output "website_endpoint" {
  description = "S3 website endpoint hostname"
  value       = aws_s3_bucket_website_configuration.frontend.website_endpoint
}

output "website_url" {
  description = "HTTP URL for the static site"
  value       = "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}"
}

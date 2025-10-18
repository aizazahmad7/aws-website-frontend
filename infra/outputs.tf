# outputs.tf — corrected to match main.tf

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (for invalidations)"
  value       = aws_cloudfront_distribution.frontend_spa.id
}

output "cloudfront_domain_name" {
  description = "Public domain name for the SPA"
  value       = aws_cloudfront_distribution.frontend_spa.domain_name
}

output "frontend_bucket_name" {
  description = "S3 bucket name hosting the React app"
  value       = aws_s3_bucket.site.bucket
}

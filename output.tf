output "website-endpoint" {
  depends_on = [
    aws_s3_bucket.emi_bucket
  ]
  value       = aws_s3_bucket.emi_bucket.website_endpoint
  description = "AWS S3 Static websites regional endpoint"
}
resource "aws_s3_bucket" "static_site225" {
  bucket = var.bucket_name
}

resource "aws s3 bucket_website_configuration" "static_website_config" {
   bucket = aws_s3_bucket.static_site225.id

index_document {
    suffix = "index.html"

 }
}


resource "aws_s3_bucket_policy" "static_site_policy" {
  bucket = aws_s3_bucket.static_site225.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.static_site225.arn}/*"
      }
    ]
  })
}


resource "aws_s3_bucket_public_access_block" "static_site_access" {
  bucket = aws_s3_bucket.static_site225.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
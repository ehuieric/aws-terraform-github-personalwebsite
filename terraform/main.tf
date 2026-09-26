# Import the existing website bucket.
resource "aws_s3_bucket" "website_bucket" {
  bucket = "aws-personal-website-225"

  lifecycle {
    prevent_destroy = true
  }
}

import {
  to = aws_s3_bucket.website_bucket
  id = "aws-personal-website-225"
}

# Stop managing the OLD bucket without deleting it.
# These blocks require Terraform 1.7 or newer.
removed {
  from = aws_s3_bucket.static_site225

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_s3_bucket_public_access_block.static_site_access

  lifecycle {
    destroy = false
  }
}

# Keep the website bucket private.
# CloudFront accesses it through OAC and the bucket policy below.
resource "aws_s3_bucket_public_access_block" "website_access" {
  bucket = aws_s3_bucket.website_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Certificate for CloudFront.
# The AWS provider must use us-east-1.
resource "aws_acm_certificate" "ehuieric_cert" {
  domain_name       = "ericehui.com"
  validation_method = "DNS"

  subject_alternative_names = [
    "www.ericehui.com"
  ]

  tags = {
    Name = "ericehui.com SSL Certificate"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Look up the existing public hosted zone.
data "aws_route53_zone" "domain_zone" {
  name         = "ericehui.com"
  private_zone = false
}

# Create the certificate's DNS validation records.
resource "aws_route53_record" "ehuieric_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.ehuieric_cert.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.domain_zone.zone_id
  name    = each.value.name
  records = [each.value.record]
  ttl     = 60
  type    = each.value.type
}

# Wait for ACM to validate the certificate.
resource "aws_acm_certificate_validation" "ehuieric_cert_validation" {
  certificate_arn = aws_acm_certificate.ehuieric_cert.arn

  validation_record_fqdns = [
    for record in aws_route53_record.ehuieric_cert_validation :
    record.fqdn
  ]
}

# Allow CloudFront to sign requests to S3.
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "oac-${aws_s3_bucket.website_bucket.bucket}"
  description                       = "OAC for ${aws_s3_bucket.website_bucket.bucket}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    origin_id                = "S3-${aws_s3_bucket.website_bucket.bucket}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "index.html"

  aliases = [
    "ericehui.com",
    "www.ericehui.com"
  ]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website_bucket.bucket}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate_validation.ehuieric_cert_validation.certificate_arn
    ssl_support_method  = "sni-only"
  }
}

# Allow only this CloudFront distribution to read bucket objects.
resource "aws_s3_bucket_policy" "static_site225_policy" {
  bucket = aws_s3_bucket.website_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "cloudfront.amazonaws.com"
        }

        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website_bucket.arn}/*"

        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
          }
        }
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.website_access
  ]
}

# Route both domain names to CloudFront over IPv4.
resource "aws_route53_record" "website_a" {
  for_each = toset([
    "ericehui.com",
    "www.ericehui.com"
  ])

  zone_id = data.aws_route53_zone.domain_zone.zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

# Route both domain names to CloudFront over IPv6.
resource "aws_route53_record" "website_aaaa" {
  for_each = toset([
    "ericehui.com",
    "www.ericehui.com"
  ])

  zone_id = data.aws_route53_zone.domain_zone.zone_id
  name    = each.value
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}
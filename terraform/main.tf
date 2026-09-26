resource "aws_s3_bucket" "static_site225" {
  bucket = var.bucket_name
}

# resource "aws_s3_bucket_website_configuration" "static_website_config" {
#    bucket = aws_s3_bucket.static_site225.id

# index_document {
#     suffix = "index.html"

#  }
# }


resource "aws_s3_bucket_public_access_block" "static_site_access" {
  bucket = aws_s3_bucket.static_site225.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# resource "aws_s3_bucket_policy" "static_site_policy" {
#   bucket = aws_s3_bucket.static_site225.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect    = "Allow"
#         Principal = "*"
#         Action    = "s3:GetObject"
#         Resource  = "${aws_s3_bucket.static_site225.arn}/*"
#       }
#     ]
#   })


#    depends_on = [ aws_s3_bucket_public_access_block.static_site_access ]
# }

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

data "aws_route53_zone" "domain_zone" {
  name         = "ericehui.com"
  private_zone = false
}


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

resource "aws_acm_certificate_validation" "ehuieric_cert_validation" {
  certificate_arn = aws_acm_certificate.ehuieric_cert.arn
   validation_record_fqdns = [for record in aws_route53_record.ehuieric_cert_validation :
    record.fqdn
  ]
}


data "aws_s3_bucket" "existing" {
  count  = length(aws_s3_bucket.this) > 0 ? 0 : 1
  bucket = var.bucket_name
}

resource "aws_s3_bucket" "this" {
  count  = length(data.aws_s3_bucket.existing.*.id) > 0 ? 0 : 1
  bucket = var.bucket_name
  tags = {
    Name        = "MyS3Bucket"
    Environment = "Production"
  }
}

resource "aws_s3_bucket_ownership_controls" "example" {
  count  = length(aws_s3_bucket.this)
  bucket = aws_s3_bucket.this[0].id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "example" {
  count                   = length(aws_s3_bucket.this)
  bucket                  = aws_s3_bucket.this[0].id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  count = length(aws_s3_bucket.this)
  depends_on = [
    aws_s3_bucket_ownership_controls.example,
    aws_s3_bucket_public_access_block.example,
  ]

  bucket = aws_s3_bucket.this[0].id
  acl    = "public-read"
}

resource "aws_s3_bucket_versioning" "versioning_example" {
  count  = length(aws_s3_bucket.this)
  bucket = aws_s3_bucket.this[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "public_read_policy" {
  bucket = aws_s3_bucket.this[0].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.this[0].arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_website_configuration" "example" {
  count  = length(aws_s3_bucket.this)
  bucket = aws_s3_bucket.this[0].id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }

  routing_rule {
    condition {
      key_prefix_equals = "docs/"
    }
    redirect {
      replace_key_prefix_with = "documents/"
    }
  }
}

data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${length(aws_s3_bucket.this) > 0 ? aws_s3_bucket.this[0].arn : data.aws_s3_bucket.existing.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [module.cloudfront.cloudfront_distribution_arn]
    }
  }
}


module "cloudfront" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "~> 3.2.0"

  origin = [{
    domain_name = length(aws_s3_bucket.this) > 0 ? aws_s3_bucket.this[0].bucket_regional_domain_name : data.aws_s3_bucket.existing.bucket_regional_domain_name
    origin_id   = var.bucket_name
  }]

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "cloudfront with s3 ${var.bucket_name}"
  default_root_object = var.cloudfront_default_root_object
  price_class         = var.cloudfront_price_class

  default_cache_behavior = {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = var.bucket_name

    forward_values = {
      query_string = false

      cookies = {
        forward = "none"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  viewer_certificate = {
    cloudfront_default_certificate = true
  }
}

output "s3_bucket_domain_name" {
  value = data.aws_s3_bucket.existing.bucket_regional_domain_name
}

# Output the CloudFront domain name
output "cloudfront_domain_name" {
  value = module.cloudfront.cloudfront_distribution_domain_name
}

# Output the CloudFront distribution ID
output "cloudfront_distribution_id" {
  value = length(aws_s3_bucket.this) > 0 ? aws_s3_bucket.this[0].bucket_regional_domain_name : data.aws_s3_bucket.existing.bucket_regional_domain_name
}

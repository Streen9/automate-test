data "external" "bucket_exists" {
  program = ["bash", "${path.module}/check_bucket.sh", var.bucket_name]

  query = {
    bucket_name = var.bucket_name
  }
}

resource "aws_s3_bucket" "this" {
  count  = data.external.bucket_exists.result["exists"] == "true" ? 0 : 1
  bucket = var.bucket_name
  tags = {
    Name        = "MyS3Bucket"
    Environment = "Production"
  }
}

resource "aws_s3_bucket_ownership_controls" "example" {
  count  = data.external.bucket_exists.result["exists"] == "true" ? 0 : 1
  bucket = aws_s3_bucket.this[0].id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "example" {
  count                   = data.external.bucket_exists.result["exists"] == "true" ? 0 : 1
  bucket                  = aws_s3_bucket.this[0].id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  count = data.external.bucket_exists.result["exists"] == "true" ? 0 : 1
  depends_on = [
    aws_s3_bucket_ownership_controls.example,
    aws_s3_bucket_public_access_block.example,
  ]

  bucket = aws_s3_bucket.this[0].id
  acl    = "public-read"
}

resource "aws_s3_bucket_versioning" "versioning_example" {
  count  = data.external.bucket_exists.result["exists"] == "true" ? 0 : 1
  bucket = aws_s3_bucket.this[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  count  = data.external.bucket_exists.result["exists"] == "true" ? 0 : 1
  bucket = aws_s3_bucket.this[0].id
  policy = data.aws_iam_policy_document.s3_bucket_policy.json
}

resource "aws_s3_bucket_website_configuration" "example" {
  count  = data.external.bucket_exists.result["exists"] == "true" ? 0 : 1
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
    resources = ["${data.external.bucket_exists.result["exists"] == "true" ? data.aws_s3_bucket.existing.arn : aws_s3_bucket.this[0].arn}/*"]
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
    domain_name = data.external.bucket_exists.result["exists"] == "true" ? data.aws_s3_bucket.existing[0].bucket_regional_domain_name : aws_s3_bucket.this[0].bucket_regional_domain_name
    origin_id             = var.bucket_name
    origin_access_control = "s3"
  }]

  enabled                      = true
  is_ipv6_enabled              = true
  comment                      = "cloudfront with s3 ${var.bucket_name}"
  default_root_object          = var.cloudfront_default_root_object
  price_class                  = var.cloudfront_price_class
  create_origin_access_control = true

  origin_access_control = {
    s3 = {
      description      = "CloudFront access to S3"
      origin_type      = "s3"
      signing_behavior = "always"
      signing_protocol = "sigv4"
    }
  }

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

# output "s3_bucket_domain_name" {
#   value = data.external.bucket_exists.result["exists"] == "true" ? data.aws_s3_bucket.existing[0].bucket_regional_domain_name : aws_s3_bucket.this[0].bucket_regional_domain_name
# }

# Output the CloudFront domain name
output "s3_bucket_domain_name" {
  value = data.external.bucket_exists.result["exists"] == "true" && length(data.aws_s3_bucket.existing) > 0 ? data.aws_s3_bucket.existing[0].bucket_regional_domain_name : aws_s3_bucket.this[0].bucket_regional_domain_name
}

output "cloudfront_distribution_id" {
  value = module.cloudfront.cloudfront_distribution_id
}
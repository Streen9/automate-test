data "aws_s3_bucket" "existing" {
  bucket = var.bucket_name
}


# creating the s3 bucket
# creating the s3 bucket ownership control
# creating the s3 public access block
# creating the s3 bucket acl
# creating the s3 bucket versioning
# creating the s3 bucket website configuration
resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  tags = {
    Name        = "MyS3Bucket"
    Environment = "Production"
  }
}

resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.this.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.example,
    aws_s3_bucket_public_access_block.example,
  ]

  bucket = aws_s3_bucket.this.id
  acl    = "public_read"
}

resource "aws_s3_bucket_versioning" "versioning_example" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_website_configuration" "example" {
  bucket = aws_s3_bucket.this.id

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
    resources = ["${module.s3_bucket.s3_bucket_arn}/*"]
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
    domain_name = module.s3_bucket.s3_bucket_bucket_regional_domain_name
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
  value = module.s3_bucket.s3_bucket_bucket_regional_domain_name
}

# Output the CloudFront domain name
output "cloudfront_domain_name" {
  value = module.cloudfront.cloudfront_distribution_domain_name
}

# Output the CloudFront distribution ID
output "cloudfront_distribution_id" {
  value = module.cloudfront.cloudfront_distribution_id
}
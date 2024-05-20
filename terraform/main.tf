# variable "bucket_name" {
#   description = "The name of the S3 bucket"
#   type        = string
# }

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Local variable to determine if bucket exists
locals {
  bucket_exists = false
}

resource "null_resource" "check_bucket" {
  provisioner "local-exec" {
    command = <<EOT
      if aws s3api head-bucket --bucket ${var.bucket_name} --region ${data.aws_region.current.name} 2>/dev/null; then
        echo "Bucket exists"
        exit 0
      else
        echo "Bucket does not exist"
        exit 1
      fi
    EOT
    environment = {
      AWS_DEFAULT_REGION = data.aws_region.current.name
    }
  }

  triggers = {
    bucket_name = var.bucket_name
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [triggers]
  }
}

# Create the bucket only if it doesn't exist
resource "aws_s3_bucket" "this" {
  count  = local.bucket_exists ? 0 : 1
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

  bucket = aws_s3_bucket.this[0].id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "versioning_example" {
  count  = length(aws_s3_bucket.this)
  bucket = aws_s3_bucket.this[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "public_read_policy" {
  count = length(aws_s3_bucket.this)

  bucket = aws_s3_bucket.this[0].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = "*",
        Action = "s3:GetObject",
        Resource = "${aws_s3_bucket.this[0].arn}/*"
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
    resources = ["${local.bucket_exists ? "arn:aws:s3:::${var.bucket_name}/*" : aws_s3_bucket.this[0].arn}/*"]
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
    domain_name = local.bucket_exists ? var.bucket_name : aws_s3_bucket.this[0].bucket_regional_domain_name
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
  value = local.bucket_exists ? var.bucket_name : aws_s3_bucket.this[0].bucket_regional_domain_name
}

output "cloudfront_domain_name" {
  value = module.cloudfront.cloudfront_distribution_domain_name
}

output "cloudfront_distribution_id" {
  value = module.cloudfront.cloudfront_distribution_id
}

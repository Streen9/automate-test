variable "aws_region" {
  default     = "us-west-2"
  type        = string
  description = "AWS region in which the users and groups are managed with iam identity centre"
}

variable "bucket_name" {
  default = "tf-bucket-automate-test"
  type = string
}

variable "created_by" {
  default = "kalivaraprasad gonapa" 
  type = string
}

variable "object_ownership" {
  default = "BucketOwnerPreferred"
  type = string
}

variable "cloudfront_default_root_object" {
  description = "The default root object for the CloudFront distribution"
  type        = string
  default     = "index.html"
}

variable "cloudfront_origin_path" {
  description = "The CloudFront origin path"
  type        = string
  default     = ""
}

variable "cloudfront_price_class" {
  description = "The price class for the CloudFront distribution"
  type        = string
  default     = "PriceClass_All"
}
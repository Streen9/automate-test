terraform {
  required_version = ">= 0.13"
  required_providers {
    aws = {
      source          = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    encrypt           = false
    bucket            = "drishya-terraform"
    key               = "global/iam_identity.tfstate"
    region            = "us-west-2"
    dynamodb_table    = "iam_identity_table"
  }
}
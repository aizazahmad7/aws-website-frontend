terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}

provider "aws" {
  region = var.region
}

# >>> ADD this alias ONLY IF you don't already have it (needed later for ACM if/when custom domain):
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
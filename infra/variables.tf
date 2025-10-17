variable "region" {
  type    = string
  default = "ap-southeast-2"
}

variable "bucket_name" {
  type        = string
  description = "Globally-unique S3 bucket"
}

variable "project_name" {
  type    = string
  default = "aws-website"
}

variable "github_org" {
  type        = string
  description = "Your GitHub username/org"
}

variable "github_repo" {
  type        = string
  description = "This repo name (without org)"
}

variable "deploy_branch" {
  type    = string
  default = "main"
}

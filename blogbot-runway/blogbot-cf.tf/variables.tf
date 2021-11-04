variable "aws_region" {
  type        = string
  description = "the AWS region to use"
}

variable "application" {
  type = string
  description = "name of the application"
}

variable "bucket_name" {
  description = "the name of the bucket with your blog files"
  type = string
}

variable "bucket_region" {
  description = "the region of the bucket with your blog files"
  type = string
}

variable "hosted_zone" {
  type = string
  description = "your hosted zone in route 53"
}

variable "site" {
  description = "the prefix of your site URL, i.e. 'blog'"
  type = string
  default = "blog"
}
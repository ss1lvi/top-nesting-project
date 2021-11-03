terraform {
  backend "s3" {
    key = "blogbot-cf.tfstate"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.27"
    }
  }
  required_version = "~> 1.0"
}

provider "aws" {
  profile = "default"
  region  = var.aws_region
  default_tags {
    tags = {
      Environment = terraform.workspace
      Application = var.application
    }
  }
}

provider "aws" {
# cloudfront/ACM certificates require us-east-1 region
  alias = "east1"
  region  = "us-east-1"
}

# # data

# data "terraform_remote_state" "blogbot" {
#   backend = "s3"
#   config = {
#     bucket = "ssilvidi-dev-tf-state-terraformstatebucket-1my31yzv88c0f"
#     region = "us-east-2"
#     key = "env:/dev/blogbot.tfstate"
#    }
# }

data "aws_route53_zone" "myzone" {
  provider = aws.east1

  name         = var.hosted_zone
  private_zone = false
}

# resources

resource "aws_acm_certificate" "cert" {
  provider = aws.east1

  domain_name       = "${var.site}.${var.hosted_zone}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "www" {
  provider = aws.east1

  zone_id = data.aws_route53_zone.myzone.zone_id
  name    = "${var.site}.${var.hosted_zone}"
  type    = "A"
  alias {
    # name = trimprefix(data.terraform_remote_state.imgmgr.outputs.cloudfront_url, "https://")
    name = aws_cloudfront_distribution.cf.domain_name
    # zone_id = data.terraform_remote_state.imgmgr.outputs.cloudfront_zone_id
    zone_id = aws_cloudfront_distribution.cf.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "validation" {
  provider = aws.east1

  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.myzone.zone_id
}

resource "aws_acm_certificate_validation" "example" {
  provider = aws.east1

  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}

data "aws_s3_bucket" "blogbucket" {
  bucket = var.bucket_name
}

resource "aws_cloudfront_distribution" "cf" {
  enabled = true
  price_class = "PriceClass_100"

  aliases = ["${var.site}.${var.hosted_zone}"]

  origin {
    domain_name = "${data.aws_s3_bucket.blogbucket.bucket}.s3-website.${data.aws_s3_bucket.blogbucket.region}.amazonaws.com"
    origin_id = "${var.application}-${terraform.workspace}-origin"

    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods = [ "GET", "HEAD" ]
    cached_methods = [ "GET", "HEAD" ]
    target_origin_id = "${var.application}-${terraform.workspace}-origin"
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    viewer_protocol_policy = "redirect-to-https"
  }

  viewer_certificate {
    # configures certificates if cf_alias variable exists
    acm_certificate_arn = aws_acm_certificate.cert.arn
    ssl_support_method = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}
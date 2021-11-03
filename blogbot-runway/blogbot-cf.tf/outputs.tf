output "domain_name" {
  value = aws_route53_record.www.name
}

output "cert" {
  value = aws_acm_certificate.cert.arn
}

output "blog" {
  value = "https://${aws_route53_record.www.name}"
}
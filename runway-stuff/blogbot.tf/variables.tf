variable "aws_region" {
    description = "the AWS region"
    type = string
}

variable "application" {
  description = "name of the application"
  type = string
}

variable "email_address" {
  description = "email addresses that will receive article approval emails"
  type = set(string)
}

variable "schedule" {
  description = "how often (in minutes) should a new post be written? (must be 2 or more)"
  type = number
  default = 10
}
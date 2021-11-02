terraform {
 backend "s3" {
   key = "blogbot.tfstate"
 }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.27"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
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

# get AWS account number, for use in ARNs later
data "aws_caller_identity" "current" {}

data "aws_cloudformation_stack" "sls_output" {
  # name = "${var.application}-${terraform.workspace}"
  name = "markov-writer-dev"
}

# commented out - 
# instead of creating a bucket, will use the one SLS creates
# resource "aws_s3_bucket" "files" {
#   bucket_prefix = "${var.application}-${terraform.workspace}-${var.aws_region}-"
#   acl = "private"
# }

data "aws_s3_bucket" "blogbucket" {
  bucket = data.aws_cloudformation_stack.sls_output.outputs["BlogBucket"]
}

resource "aws_s3_bucket_object" "corpora" {
  # upload any corpus files to the bucket
  for_each = fileset("corpora/", "*")

  # bucket = aws_s3_bucket.files.id
  bucket = data.aws_s3_bucket.blogbucket.id
  key = each.value
  source = "corpora/${each.value}"
  etag = filemd5("corpora/${each.value}")
}

resource "aws_iam_role" "blogbot_role" {
  name_prefix = "${var.application}-${terraform.workspace}-state-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })

  inline_policy {
    name = "invokeLambdas"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = ["lambda:InvokeFunction"]
          Effect = "Allow"
          Resource = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:*"
        }
      ]
    })
  }
}

resource "aws_sfn_state_machine" "blogbot" {
  name = "${var.application}-${terraform.workspace}"
  role_arn = aws_iam_role.blogbot_role.arn

  definition = <<EOF
{
  "StartAt": "Lambda Invoke",
  "TimeoutSeconds": 3600,
  "States": {
    "Lambda Writer": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "arn:aws:lambda:us-east-2:329082876876:function:markov-writer-dev-writer:$LATEST",
        "Payload.$": "$"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "Next": "Lambda Callback"
    },
    "Lambda Callback": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke.waitForTaskToken",
      "Parameters": {
        "FunctionName": ${aws_lambda_function.lambda_sendemail.arn},
        "Payload": {
          "ExecutionContext.$": "$$",
          "APIGatewayEndpoint": ${aws_api_gateway_stage.approval.invoke_url},
          "BlogPost.$": "$.Payload"
        }
      },
      "Next": "ManualApprovalChoiceState"
    },
    "ManualApprovalChoiceState": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.Status",
          "StringEquals": "Approved!",
          "Next": "Lambda Publisher"
        },
        {
          "Variable": "$.Status",
          "StringEquals": "Rejected!",
          "Next": "RejectedPassState"
        }
      ]
    },
    "Lambda Publisher": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:us-east-2:329082876876:function:markov-writer-dev-publisher:$LATEST"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "Next": "ApprovedPassState"
    },
    "ApprovedPassState": {
      "Type": "Pass",
      "End": true
    },
    "RejectedPassState": {
      "Type": "Pass",
      "End": true
    }
  }
}
EOF
}

# Lambda functions

# lambda approval

data "archive_file" "lambda_approval" {
  type = "zip"

  source_dir  = "${path.module}/lambda/ApprovalFunction"
  output_path = "${path.module}/ApprovalFunction.zip"
}

resource "aws_s3_bucket_object" "lambda_approval" {
  # bucket = aws_s3_bucket.files.id
  bucket = data.aws_s3_bucket.blogbucket.id

  key = "ApprovalFunction.zip"
  source = data.archive_file.lambda_approval.output_path

  etag = filemd5(data.archive_file.lambda_approval.output_path)
}

resource "aws_lambda_function" "lambda_approval" {
  function_name = "ApprovalFunction"

  # s3_bucket = aws_s3_bucket.files.id
  s3_bucket = data.aws_s3_bucket.blogbucket.id
  s3_key = aws_s3_bucket_object.lambda_approval.key

  runtime = "nodejs12.x"
  handler = "index.handler"

  source_code_hash = data.archive_file.lambda_approval.output_base64sha256

  role = aws_iam_role.lambda_approval_exec.arn
}

resource "aws_cloudwatch_log_group" "lambda_approval" {
  name = "/aws/lambda/${aws_lambda_function.lambda_approval.function_name}"

  retention_in_days = 30
}

resource "aws_iam_role" "lambda_approval_exec" {
  name_prefix = "lambda_approval"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  inline_policy {
    name = "cloudwatchlogs_policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = ["logs:*"]
          Effect = "Allow"
          Resource = "arn:aws:logs:*:*:*"
        }
      ]
    })
  }

  inline_policy {
    name = "stepfunctions_policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = ["states:SendTaskFailure","states:SendTaskSuccess"]
          Effect = "Allow"
          Resource = "*"
        }
      ]
    })
  }
}

# lambda sendemail

data "archive_file" "lambda_sendemail" {
  type = "zip"

  source_dir  = "${path.module}/lambda/SendEmailFunction"
  output_path = "${path.module}/SendEmailFunction.zip"
}

resource "aws_s3_bucket_object" "lambda_sendemail" {
  # bucket = aws_s3_bucket.files.id
  bucket = data.aws_s3_bucket.blogbucket.id

  key = "SendEmailFunction.zip"
  source = data.archive_file.lambda_sendemail.output_path

  etag = filemd5(data.archive_file.lambda_sendemail.output_path)
}

resource "aws_lambda_function" "lambda_sendemail" {
  function_name = "SendEmailFunction"

  # s3_bucket = aws_s3_bucket.files.id
  s3_bucket = data.aws_s3_bucket.blogbucket.id
  s3_key = aws_s3_bucket_object.lambda_sendemail.key

  runtime = "nodejs12.x"
  handler = "index.handler"

  source_code_hash = data.archive_file.lambda_sendemail.output_base64sha256

  role = aws_iam_role.lambda_sendemail_exec.arn

  environment {
    variables = {
      "SNS_TOPIC" = aws_sns_topic.approval.arn
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_sendemail" {
  name = "/aws/lambda/${aws_lambda_function.lambda_sendemail.function_name}"

  retention_in_days = 30
}

resource "aws_iam_role" "lambda_sendemail_exec" {
  name_prefix = "lambda_sendemail"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  inline_policy {
    name = "cloudwatchlogs_policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = ["logs:*"]
          Effect = "Allow"
          Resource = "arn:aws:logs:*:*:*"
        }
      ]
    })
  }

  inline_policy {
    name = "sns_email_policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = ["SNS:Publish"]
          Effect = "Allow"
          Resource = aws_sns_topic.approval.arn
        }
      ]
    })
  }
}

# API gateway

resource "aws_api_gateway_rest_api" "approval" {
  name = "${var.application}-${terraform.workspace}-api"
}

resource "aws_api_gateway_resource" "approval" {
  rest_api_id = aws_api_gateway_rest_api.approval.id
  parent_id = aws_api_gateway_rest_api.approval.root_resource_id
  path_part = "execution"
}

resource "aws_api_gateway_method" "approval" {
  rest_api_id = aws_api_gateway_rest_api.approval.id
  resource_id = aws_api_gateway_resource.approval.id
  http_method = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "response_302" {
  rest_api_id = aws_api_gateway_rest_api.approval.id
  resource_id = aws_api_gateway_resource.approval.id
  http_method = aws_api_gateway_method.approval.http_method
  status_code = "302"

  response_parameters = {
    "method.response.header.Location" = true
  }
}

resource "aws_api_gateway_integration" "approval" {
  rest_api_id = aws_api_gateway_rest_api.approval.id
  resource_id = aws_api_gateway_resource.approval.id
  http_method = aws_api_gateway_method.approval.http_method
  integration_http_method = "POST"
  type = "AWS"
  uri = aws_lambda_function.lambda_approval.invoke_arn

  request_templates = {
    "application/json" = <<EOF
{
  "body" : $input.json('$'),
  "headers": {
    #foreach($header in $input.params().header.keySet())
    "$header": "$util.escapeJavaScript($input.params().header.get($header))" #if($foreach.hasNext),#end

    #end
  },
  "method": "$context.httpMethod",
  "params": {
    #foreach($param in $input.params().path.keySet())
    "$param": "$util.escapeJavaScript($input.params().path.get($param))" #if($foreach.hasNext),#end

    #end
  },
  "query": {
    #foreach($queryParam in $input.params().querystring.keySet())
    "$queryParam": "$util.escapeJavaScript($input.params().querystring.get($queryParam))" #if($foreach.hasNext),#end

    #end
  }
}
EOF
  }
}

resource "aws_api_gateway_integration_response" "approval" {
  depends_on = [ aws_api_gateway_integration.approval ]
  rest_api_id = aws_api_gateway_rest_api.approval.id
  resource_id = aws_api_gateway_resource.approval.id
  http_method = aws_api_gateway_method.approval.http_method
  status_code = aws_api_gateway_method_response.response_302.status_code

  response_parameters = {
    "method.response.header.Location" = "integration.response.body.headers.Location"
  }
}

resource "aws_api_gateway_account" "approval" {
  cloudwatch_role_arn = aws_iam_role.cloudwatch_logs.arn
}

resource "aws_iam_role" "cloudwatch_logs" {
  name_prefix = "${var.application}-${terraform.workspace}-apigw-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })

  inline_policy {
    name = "api-gateway-logs-policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = ["logs:*"]
          Effect = "Allow"
          Resource = "*"
        }
      ]
    })
  }
}

resource "aws_api_gateway_deployment" "approval" {
  depends_on = [ aws_api_gateway_method.approval ]

  rest_api_id = aws_api_gateway_rest_api.approval.id
  stage_name = "dummyStage"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "approval" {
  depends_on = [ aws_api_gateway_account.approval ]

  deployment_id = aws_api_gateway_deployment.approval.id
  rest_api_id = aws_api_gateway_rest_api.approval.id
  stage_name = "states"
}

resource "aws_api_gateway_method_settings" "approval" {
  rest_api_id = aws_api_gateway_rest_api.approval.id
  stage_name = aws_api_gateway_stage.approval.stage_name
  method_path = "*/*"

  settings {
    data_trace_enabled = true
    logging_level = "INFO"
  }
}

# resource "aws_lambda_permission" "api_gw" {
#   statement_id  = "AllowExecutionFromAPIGateway"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.lambda_approval.function_name
#   principal     = "apigateway.amazonaws.com"
# 
#   source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
# }

# SNS topic and subscriptions

resource "aws_sns_topic" "approval" {
  name_prefix = "${var.application}-${terraform.workspace}-topic"
}

resource "aws_sns_topic_subscription" "approval_subs" {
  for_each = var.email_address

  topic_arn = aws_sns_topic.approval.arn
  protocol = "email"
  endpoint = each.key
}

resource "aws_cloudwatch_event_rule" "scheduler" {
  name_prefix = "${var.application}-${terraform.workspace}-scheduler"
  description = "schedule for new blog posts to be posted"
  schedule_expression = "rate(${var.schedule} minutes)"
}

resource "aws_cloudwatch_event_target" "sfn" {
  rule = aws_cloudwatch_event_rule.scheduler.name
  arn = aws_sfn_state_machine.blogbot.arn
  role_arn = aws_iam_role.events_sfn_role.arn
}

resource "aws_iam_role" "events_sfn_role" {
  name_prefix = "${var.application}-${terraform.workspace}-events-sfn-invoke"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "events.amazonaws.com"
      }
    }]
  })

  inline_policy {
    name = "invoke-step-function"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = ["states:StartExecution"]
          Effect = "Allow"
          Resource = aws_sfn_state_machine.blogbot.arn
        }
      ]
    })
  }
}
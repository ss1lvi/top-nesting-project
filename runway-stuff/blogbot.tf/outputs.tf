output "api_gateway_invoke_url" {
  description = "the invoke url of the api gateway"
  value = aws_api_gateway_stage.approval.invoke_url
}

output "state_machine_arn" {
  description = "the arn of the state machine"
  value = aws_sfn_state_machine.blogbot.arn
}
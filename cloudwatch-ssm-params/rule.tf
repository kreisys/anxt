locals {
  event_pattern = {
    source      = ["aws.ssm"]
    detail-type = ["Parameter Store Change"]

    #resources = ["${var.ssm_path_arns}"]
  }
}

resource "aws_cloudwatch_event_rule" "this" {
  name          = "${var.cloudwatch_rule_name}"
  description   = "${var.cloudwatch_rule_description}"
  event_pattern = "${jsonencode(local.event_pattern)}"
}

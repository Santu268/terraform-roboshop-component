locals {
private_subnet_id = split(",",data.aws_ssm_parameter.private_subnet_ids.value)[0]
ami_id = data.aws_ami.ami_name.id
vpc_id = data.aws_ssm_parameter.vpc_id.value
common_name = "${var.project}-${var.env}-${var.component}"
sg_id = data.aws_ssm_parameter.sg_id.value
common_tags = {
    Project = var.project
    Env = var.env
    Terraform = "true"
    Name = "${local.common_name}"
}
zone_id = data.aws_route53_zone.primary.zone_id
domain_name = data.aws_route53_zone.primary.name
backend_alb_listener_arn= data.aws_ssm_parameter.backend_alb_listener_arn.value
frontend_alb_listener_arn= data.aws_ssm_parameter.frontend_alb_listener_arn.value
alb_listener_arn = var.component == "frontend" ? local.frontend_alb_listener_arn : local.backend_alb_listener_arn
host_header = var.component == "frontend" ? "${var.project}-${var.env}.${var.domain_name}" : "${var.component}.backed-alb-${var.env}.${var.domain_name}"
}
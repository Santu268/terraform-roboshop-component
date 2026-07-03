resource "aws_instance" "main" {
  ami           = local.ami_id
  instance_type = var.instance_type
  vpc_security_group_ids = [local.sg_id]
  subnet_id = local.private_subnet_id
  tags = local.common_tags
}

resource "terraform_data" "main" {
  triggers_replace = [
    aws_instance.main.id,
    var.script_version
      ]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    password = "DevOps321"
    host        = aws_instance.main.private_ip
  }

  provisioner "file" {
    source      = "bootstrap.sh"
    destination = "/tmp/bootstrap.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/bootstrap.sh",
      "sudo sh /tmp/bootstrap.sh ${var.component} ${var.env} ${var.app_version}"
    ]
  }
}

resource "aws_ec2_instance_state" "main" {
  instance_id = aws_instance.main.id
  state       = "stopped"
  depends_on = [terraform_data.main]
}

resource "aws_ami_from_instance" "main" {
  name               = "${local.common_name}-${var.app_version}-${aws_instance.main.id}"
  source_instance_id = aws_instance.main.id
  depends_on = [aws_ec2_instance_state.main]
  tags = {
    Name = "${local.common_name}-${var.app_version}-${aws_instance.main.id}"
  }
}

resource "aws_launch_template" "main" {
  name = "${local.common_name}"

  image_id = aws_ami_from_instance.main.id

  instance_initiated_shutdown_behavior = "terminate"

  instance_type = var.instance_type

  vpc_security_group_ids = [local.sg_id]
  update_default_version = true

  tag_specifications {
    resource_type = "instance"

    tags = merge (
      local.common_tags,
      {
        Name = "${local.common_name}-${var.app_version}-${aws_instance.main.id}"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge (
      local.common_tags,
      {
        Name = "${local.common_name}-${var.app_version}-${aws_instance.main.id}"
      }
    )
  }

  tags = merge (
      local.common_tags,
      {
        Name = "${local.common_name}-${var.app_version}-${aws_instance.main.id}"
      }
    )
}

resource "aws_lb_target_group" "main" {
  name     = "${local.common_name}"
  port     = var.component == "frontend" ? "80" : "8080"
  protocol = "HTTP"
  vpc_id   = local.vpc_id
  deregistration_delay = 30
 health_check {

  healthy_threshold = 2
  interval =10
  matcher = "200-299"
  path = var.component == "frontend" ? "/" : "/health"
  protocol = "HTTP"
  port = var.component == "frontend" ? "80" : "8080"
  timeout = 5
  unhealthy_threshold = 2
 }

}


resource "aws_autoscaling_group" "main" {
  name                      = "${local.common_name}"
  max_size                  = 10
  min_size                  = 1
  health_check_grace_period = 120
  health_check_type         = "ELB"
  desired_capacity          = 2
  force_delete              = true
  vpc_zone_identifier       = [local.private_subnet_id]
  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    }
target_group_arns = [aws_lb_target_group.main.arn]
 dynamic "tag"{
  for_each = local.common_tags

  content {
    key = tag.key
    value = tag.value
    propagate_at_launch = true
  }
 }
  
  timeouts {
    delete = "15m"
  }
  
}

resource "aws_autoscaling_policy" "main" {
  name                   = "${local.common_name}"
  estimated_instance_warmup = 120
  autoscaling_group_name = aws_autoscaling_group.main.name
  policy_type            = "TargetTrackingScaling"
   target_tracking_configuration  {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 75.0 # Target average CPU utilization percentage
  }
}

resource "aws_lb_listener_rule" "alb_rule" {
  listener_arn = local.alb_listener_arn
  priority     = var.rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    path_pattern {
      values = [ local.host_header ]
    }
  }

}

# resource "terraform_data" "component_terminate" {
#   triggers_replace = [
#      aws_instance.main.id
#   ]
# depends_on = [aws_autoscaling_group.main]

#   provisioner "local-exec" {
#     command = "aws ec2 terminate-instances --instance-ids ${aws_instance.main.id}"
#   }
# }
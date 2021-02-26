#
# Ensure Secret exists
#
data "aws_secretsmanager_secret" "password" {
  name = var.aws_secretmanager_secret_id
}

#
# Find BIG-IP AMI
#
data "aws_ami" "f5_ami" {
  most_recent = true
  owners      = ["679593333241"]

  filter {
    name   = "name"
    values = [var.f5_ami_search_name]
  }
}

resource "aws_launch_configuration" "proxy_lc" {
  name_prefix   = "${var.prefix}-proxy-lc-"
  key_name      = var.ec2_key_name
  image_id      = data.aws_ami.f5_ami.id
  instance_type = var.ec2_instance_type
  associate_public_ip_address = var.create_management_public_ip
  security_groups = var.public_subnet_security_group_ids
  iam_instance_profile = aws_iam_instance_profile.bigip_profile.name
  user_data = templatefile(
    "${path.module}/f5_onboard.tmpl",
    {
      RI_URL      = var.RI_URL
      DO_URL      = var.DO_URL,
      AS3_URL     = var.AS3_URL,
      TS_URL      = var.TS_URL,
      libs_dir    = var.libs_dir,
      onboard_log = var.onboard_log,
      bigip_username = var.f5_username
      secret_id      = var.aws_secretmanager_secret_id
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# https://medium.com/@endofcake/using-terraform-for-zero-downtime-updates-of-an-auto-scaling-group-in-aws-60faca582664

resource "aws_autoscaling_group" "proxy_asg" {
  #name                     = "${var.prefix}-proxy-asg"
  name                      = aws_launch_configuration.proxy_lc.name
  vpc_zone_identifier       = var.vpc_public_subnet_ids
  #availability_zones        = ["us-west-2a","us-west-2b"]
  max_size                  = var.scale_max
  min_size                  = var.scale_min
  desired_capacity          = var.scale_desired
  health_check_grace_period = 300
  health_check_type         = "EC2"
  force_delete              = true
  launch_configuration      = aws_launch_configuration.proxy_lc.name
  lifecycle {
    create_before_destroy = true
  }
  tag {
    key = "Name"
    value = "${var.prefix}-proxy-asg"
    propagate_at_launch = true
  }

  tag {
    key = "environment"
    value = var.prefix
    propagate_at_launch = true
  }

}

resource "aws_autoscaling_policy" "proxy_asg_policy" {
  name                   = "${var.prefix}-proxy-asg-policy"
  scaling_adjustment     = 2
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.proxy_asg.name
}

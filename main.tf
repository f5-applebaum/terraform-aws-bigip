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

# resource "aws_launch_configuration" "bigip_lc" {
#   name_prefix   = "${var.prefix}-bigip-lc-"
#   key_name      = var.ec2_key_name
#   image_id      = data.aws_ami.f5_ami.id
#   instance_type = var.ec2_instance_type
#   associate_public_ip_address = var.create_management_public_ip
#   security_groups = var.subnet_security_group_ids
#   iam_instance_profile = var.aws_iam_instance_profile
#   user_data = templatefile(
#     "${path.module}/f5_onboard.tmpl",
#     {
#       RI_URL      = var.RI_URL,
#       RI_CONFIG   = var.RI_CONFIG
#     }
#   )
#   # https://medium.com/@endofcake/using-terraform-for-zero-downtime-updates-of-an-auto-scaling-group-in-aws-60faca582664
#   lifecycle {
#     create_before_destroy = true
#   }
# }

resource "random_id" "r_id" {
  byte_length = 4
}

# Create BIG-IP launch template
resource "aws_launch_template" "bigip-lt" {
  name          = "${var.prefix}-bigip-lt"
  update_default_version = true
  image_id      = data.aws_ami.f5_ami.id
  instance_type = var.ec2_instance_type
  key_name      = var.ec2_key_name
  iam_instance_profile {
    name = var.aws_iam_instance_profile
  }
  user_data     = base64encode(templatefile(
    "${path.module}/f5_onboard.tmpl",
    {
      RI_URL      = var.RI_URL,
      RI_CONFIG   = var.RI_CONFIG
    }
  )
  )

  network_interfaces {
    device_index          = 0
    description           = "eth0"
    delete_on_termination = true
    security_groups       = var.subnet_security_group_ids
    # associate_public_ip_address = true # Can't use The associatePublicIPAddress parameter cannot be specified when launching with multiple network interfaces.
    # subnet_id             = 
  }
  network_interfaces {
    device_index          = 1
    description           = "eth1"
    delete_on_termination = true
    security_groups       = var.subnet_security_group_ids
    # subnet_id             = 
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name  = "${var.prefix}-bigip-lt-instance"
      Env = var.prefix
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "bigip_asg" {
  name                     = "${var.prefix}-bigip-asg"
  vpc_zone_identifier       = var.vpc_subnet_ids
  #availability_zones        = [var.availabilty_zones]
  max_size                  = var.scale_max
  min_size                  = var.scale_min
  desired_capacity          = var.scale_desired
  health_check_grace_period = 300
  health_check_type         = "EC2"
  force_delete              = true

  #launch_configuration      = aws_launch_configuration.bigip_lc.name
  launch_template {
    id      = aws_launch_template.bigip-lt.id
    version = "$Latest"
  }

  lifecycle {
    create_before_destroy = true
  }
  tag {
    key = "Name"
    value = "${var.prefix}-bigip-asg"
    propagate_at_launch = true
  }

  tag {
    key = "environment"
    value = var.prefix
    propagate_at_launch = true
  }
  target_group_arns = var.target_group_arns

}

resource "aws_autoscaling_policy" "bigip_asg_policy" {
  name                   = "${var.prefix}-bigip-asg-policy"
  scaling_adjustment     = 2
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.bigip_asg.name
}

provider "aws" {
  region = var.region
}

#
# Create a random id
#
resource "random_id" "id" {
  byte_length = 2
}

#
# Create the VPC 
#
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name                 = format("%s-vpc-%s", local.prefix, random_id.id.hex)
  cidr                 = local.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  azs = var.availabilityZones

  public_subnets = [
    for num in range(length(var.availabilityZones)) :
    cidrsubnet(local.cidr, 8, num)
  ]

  # using the database subnet method since it allows a public route
  database_subnets = [
    for num in range(length(var.availabilityZones)) :
    cidrsubnet(local.cidr, 8, num + 10)
  ]
  create_database_subnet_group           = true
  create_database_subnet_route_table     = true
  create_database_internet_gateway_route = true

  private_subnets = [
    for num in range(length(var.availabilityZones)) :
    cidrsubnet(local.cidr, 8, num + 20)
  ]

  tags = {
    Name        = format("%s-vpc-%s", local.prefix, random_id.id.hex)
    Terraform   = "true"
    Environment = "dev"
  }
}

#
# Create a security group for port 80 traffic
#
module "web_server_sg" {
  source = "terraform-aws-modules/security-group/aws//modules/http-80"

  name        = format("%s-web-server-%s", local.prefix, random_id.id.hex)
  description = "Security group for web-server with HTTP ports"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = [local.allowed_app_cidr]
}

#
# Create a security group for port 443 traffic
#
module "web_server_secure_sg" {
  source = "terraform-aws-modules/security-group/aws//modules/https-443"

  name        = format("%s-web-server-secure-%s", local.prefix, random_id.id.hex)
  description = "Security group for web-server with HTTPS ports"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = [local.allowed_app_cidr]
}

#
# Create a security group for SSH traffic
#
module "ssh_secure_sg" {
  source = "terraform-aws-modules/security-group/aws//modules/ssh"

  name        = format("%s-ssh-%s", local.prefix, random_id.id.hex)
  description = "Security group for SSH ports open within VPC"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = [local.allowed_mgmt_cidr]
}

#
# Create a security group for port 8443 traffic
#
module "bigip_mgmt_secure_sg" {
  source = "terraform-aws-modules/security-group/aws//modules/https-8443"

  name        = format("%s-bigip-mgmt-%s", local.prefix, random_id.id.hex)
  description = "Security group for BIG-IP MGMT Interface"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = [local.allowed_mgmt_cidr]
}

#
# Create random password for BIG-IP
#
resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = " #%*+,-./:=?@[]^_~"
}

#
# Create Secret Store and Store BIG-IP Password
#
resource "aws_secretsmanager_secret" "bigip" {
  name = format("%s-bigip-secret-%s", var.prefix, random_id.id.hex)
}
resource "aws_secretsmanager_secret_version" "bigip-pwd" {
  secret_id     = aws_secretsmanager_secret.bigip.id
  secret_string = random_password.password.result
}


#
# Create IAM Role
#

data "aws_iam_policy_document" "bigip_role" {
  version = "2012-10-17"
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bigip_role" {
  name               = format("%s-bigip-role", var.prefix)
  assume_role_policy = data.aws_iam_policy_document.bigip_role.json

  tags = {
    tag-key = "tag-value"
  }
}

resource "aws_iam_instance_profile" "bigip_profile" {
  name = format("%s-bigip-profile", var.prefix)
  role = aws_iam_role.bigip_role.name
}

resource "aws_iam_role_policy" "bigip_policy" {
  name   = format("%s-bigip-policy", var.prefix)
  role   = aws_iam_role.bigip_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Action": [
            "ec2:DescribeInstances",
            "ec2:DescribeInstanceStatus",
            "ec2:DescribeAddresses",
            "ec2:AssociateAddress",
            "ec2:DisassociateAddress",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DescribeNetworkInterfaceAttribute",
            "ec2:DescribeRouteTables",
            "ec2:ReplaceRoute",
            "ec2:CreateRoute",
            "ec2:assignprivateipaddresses",
            "sts:AssumeRole",
            "s3:ListAllMyBuckets"
        ],
        "Resource": [
            "*"
        ],
        "Effect": "Allow"
    },
    {
        "Effect": "Allow",
        "Action": [
            "secretsmanager:GetResourcePolicy",
            "secretsmanager:GetSecretValue",
            "secretsmanager:DescribeSecret",
            "secretsmanager:ListSecretVersionIds",
            "secretsmanager:UpdateSecretVersionStage"
        ],
        "Resource": [
            "arn:aws:secretsmanager:${var.region}:${module.vpc.vpc_owner_id}:secret:*"
        ]
    }
  ]
}
EOF
}


#
# Create INGRESS FOR WAF
#

module "nlb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 5.0"
  
  name = format("%s-nlb-%s", local.prefix, random_id.id.hex)

  load_balancer_type = "network"

  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets
  
  # access_logs = {
  #   bucket = "my-nlb-logs"
  # }

  target_groups = [
    {
      name_prefix      = "bigip-"
      backend_protocol = "TCP"
      backend_port     = 80
      target_type      = "instance"
    }
  ]

  # https_listeners = [
  #   {
  #     port               = 443
  #     protocol           = "TLS"
  #     certificate_arn    = "arn:aws:iam::123456789012:server-certificate/test_cert-123456789012"
  #     target_group_index = 0
  #   }
  # ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "TCP"
      target_group_index = 0
    }
  ]

  tags = {
    Environment = "Example NLB"
  }
}

#
# Example of Using BIG-IP Autoscaling Module 
# and sending just the BIG-IP configuration file (Runtime Init Config) 
# and Rutime-Init Package to Install 
# as the "input" for user_data
#
# module bigip {
#   source = "../../"

#   prefix = format(
#     "%s-bigip_asg_with_new_vpc-%s",
#     local.prefix,
#     random_id.id.hex
#   )

#   # Placement
#   vpc_subnet_ids  = module.vpc.public_subnets

#   # Scale
#   scale_min                   = var.scale_min
#   scale_max                   = var.scale_max
#   scale_desired               = var.scale_desired


#   # Security
#   ec2_key_name                = var.ec2_key_name
#   aws_iam_instance_profile    = aws_iam_instance_profile.bigip_profile.name
#   subnet_security_group_ids = [
#     module.ssh_secure_sg.this_security_group_id,
#     module.bigip_mgmt_secure_sg.this_security_group_id,
#     module.web_server_sg.this_security_group_id,
#     module.web_server_secure_sg.this_security_group_id
#   ]

#   # Instance
#   f5_ami_search_name          = var.f5_ami_search_name
#   ec2_instance_type           = var.ec2_instance_type

#   # BIG-IP CONFIG
#   RI_URL = var.RI_URL
#   RI_CONFIG = templatefile(
#     "${path.module}/runtime_init_conf.tmpl",
#     {
#       bigip_username = var.f5_username
#       secret_id      = aws_secretsmanager_secret.bigip.id
#     }
#   )
#   # LB
#   target_group_arns = module.nlb.target_group_arns

# }

#
# Example of Using AWS Native Terraform Autoscaling Module 
# https://registry.terraform.io/modules/terraform-aws-modules/autoscaling/aws/1.0.0
# and sending entire user_data script ( startup script + BIG-IP configuration)
#

data "aws_ami" "f5_ami" {
  most_recent = true
  owners      = ["679593333241"]

  filter {
    name   = "name"
    values = [var.f5_ami_search_name]
  }
}


module "bigip_asg_module" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 3.0"

  name = "BIG-IP Autoscale Group"

  # Auto scaling group
  asg_name                  = format("%s-bigip-asg", local.prefix)
  health_check_type         = "EC2"

  # Placement / Network
  vpc_zone_identifier       = module.vpc.public_subnets

  # Scale
  min_size                  = var.scale_min
  max_size                  = var.scale_max
  desired_capacity          = var.scale_desired
  wait_for_capacity_timeout = 0

  # Launch configuration
  lc_name = format("%s-bigip-lc", local.prefix)

  # Security
  key_name              = var.ec2_key_name
  iam_instance_profile  = aws_iam_instance_profile.bigip_profile.name
  security_groups = [
    module.ssh_secure_sg.this_security_group_id,
    module.bigip_mgmt_secure_sg.this_security_group_id,
    module.web_server_sg.this_security_group_id,
    module.web_server_secure_sg.this_security_group_id
  ]
  associate_public_ip_address = local.create_management_public_ip

  # Instance
  #image_id        = "ami-0a248ce88bcc7bd23"
  image_id        = data.aws_ami.f5_ami.id
  instance_type   = var.ec2_instance_type

  # ebs_block_device = [
  #   {
  #     device_name           = "/dev/xvda"
  #     volume_type           = "gp2"
  #     volume_size           = "100"
  #     delete_on_termination = true
  #   },
  #   {
  #     device_name           = "/dev/xvdb"
  #   }
  # ]

  root_block_device = [
    {
      volume_size = "100"
      volume_type = "gp2"
    },
  ]

  # BIG-IP CONFIG
  user_data = templatefile(
    "${path.module}/user_data_bigip.tmpl",
    {
      RI_URL         = var.RI_URL
      bigip_username = var.f5_username
      secret_id      = aws_secretsmanager_secret.bigip.id
    }
  )

  tags = [
    {
      key                 = "Application"
      value               = "WAF"
      propagate_at_launch = true
    },
    {
      key                 = "Name"
      value               = "BIG-IP ASG Instance"
      propagate_at_launch = true
    },
    {
      key                 = "Environment"
      value               = "dev"
      propagate_at_launch = true
    }
  ]

    # LB
  target_group_arns = module.nlb.target_group_arns

}



#
# Find APP AMI
#
data "aws_ami" "app_ami" {
  most_recent = true
  owners      = ["125523088429"]

  filter {
    name   = "name"
    values = [ "CentOS 7.8.2003 x86_64" ]
  }
}


module "application" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 3.0"

  name = "Application Autoscale Group"

  # Launch configuration
  lc_name = format("%s-app-lc", local.prefix)

  # Security
  key_name        = var.ec2_key_name
  security_groups = [
    module.web_server_sg.this_security_group_id,
    module.web_server_secure_sg.this_security_group_id
  ]
  associate_public_ip_address = true

  #image_id        = "ami-0a248ce88bcc7bd23"
  image_id        = data.aws_ami.app_ami.id
  instance_type   = "t2.small"

  root_block_device = [
    {
      volume_size = "50"
      volume_type = "gp2"
    },
  ]

  # ebs_block_device = [
  #   {
  #     device_name           = "/dev/xvdz"
  #     volume_type           = "gp2"
  #     volume_size           = "50"
  #     delete_on_termination = true
  #   },
  # ]

  # Auto scaling group
  asg_name                  = format("%s-app-asg", local.prefix)
  vpc_zone_identifier       = module.vpc.public_subnets
  health_check_type         = "EC2"
  min_size                  = 0
  max_size                  = 4
  desired_capacity          = 1
  wait_for_capacity_timeout = 0

  user_data = templatefile(
    "${path.module}/user_data_app.tmpl",
    {
       appContainerName = "f5devcentral/f5-demo-app:latest"
    }
  )

  tags = [
    {
      key                 = "Application"
      value               = "appAutoscaleGroup"
      propagate_at_launch = true
    },
    {
      key                 = "Name"
      value               = "Application Instance"
      propagate_at_launch = true
    },
    {
      key                 = "Environment"
      value               = "dev"
      propagate_at_launch = true
    }
  ]
}


#
# Variables used by this example
#
locals {
  prefix            = "tf-aws-bigip"
  #region            = "us-west-2"
  #availabilityZones = [format("%s%s", local.region, "a"), format("%s%s", local.region, "b")]
  create_management_public_ip = true
  cidr              = "10.0.0.0/16"
  allowed_mgmt_cidr = "0.0.0.0/0"
  allowed_app_cidr  = "0.0.0.0/0"
}

variable "prefix" {
  description = "Prefix for resources created by this module"
  type        = string
  default     = "terraform-aws-bigip-demo"
}

variable "vpc_subnet_ids" {
  description = "AWS VPC Subnet ids"
  type        = list
  default     = []
}

variable "f5_ami_search_name" {
  description = "BIG-IP AMI name to search for"
  type        = string
  default     = "F5 BIGIP-15.1.2.1* PAYG-Best 25Mbps*"
}

variable "ec2_instance_type" {
  description = "AWS EC2 instance type"
  type        = string
  default     = "m4.large"
}

variable "ec2_key_name" {
  description = "AWS EC2 Key name for SSH access"
  type        = string
}

variable "subnet_security_group_ids" {
  description = "AWS Security Group ID for BIG-IP interface"
  type        = list
  default     = []
}

variable aws_iam_instance_profile {
  description = "AWS IAM Instance Profile Name"
  type        = string
}

## Please check and update the latest RUNTIME-INIT URL from https://github.com/f5networks/f5-bigip-runtime-init/releases/latest
# always point to a specific version in order to avoid inadvertent configuration inconsistency
variable RI_URL {
  description = "URL to download the BIG-IP Runtime Init Package"
  type        = string
  default     = "https://github.com/F5Networks/f5-bigip-runtime-init/releases/download/1.2.0/f5-bigip-runtime-init-1.2.0-1.gz.run"
}

variable RI_CONFIG {
  description = "Runtime Init Config File"
  type        = string
}

# Autoscale

variable region { 
  description = "aws region"
  type        = string
  default     = "us-west-2" 
}

variable scale_min  { 
  description = "Autoscale Min Number"
  type        = number
  default     = 1 
}

variable scale_max      {
  description = "Autoscale Max Number"
  type        = number 
  default     = 3
}

variable scale_desired  {
  description = "Autoscale Desired Number"
  type        = number
  default     = 1 
}

variable create_management_public_ip  {
  description = "Autoscale Desired Number"
  type        = bool
  default     = true
}

variable target_group_arns  {
  description = "Autoscale Target Group ARNs"
  type        = list
  default     = []
}

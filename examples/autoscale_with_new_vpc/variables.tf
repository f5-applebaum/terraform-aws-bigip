#
# Variable for the EC2 Key 
# Set via CLI or via terraform.tfvars file
#
variable "ec2_key_name" {
  description = "AWS EC2 Key name for SSH access"
  type        = string
}

variable "prefix" {
  description = "Prefix for resources created by this module"
  type        = string
  default     = "terraform-aws-bigip-autoscale"
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
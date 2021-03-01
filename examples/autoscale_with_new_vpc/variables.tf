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

############ OPTIONAL BELOW ##########

variable region { 
  description = "aws region"
  type        = string
  default     = "us-west-2" 
}

variable availabilityZones {
  description = "If you want the VM placed in an AWS Availability Zone, and the AWS region you are deploying to supports it, specify the numbers of the existing Availability Zone you want to use."
  type        = list
  default     = ["us-west-2a", "us-west-2b"]
}

variable "f5_ami_search_name" {
  description = "BIG-IP AMI name to search for"
  type        = string
  default     = "F5 BIGIP-15.1.2.1* PAYG-Best 25Mbps*"
}

variable "ec2_instance_type" {
  description = "AWS EC2 instance type"
  type        = string
  default     = "m5.large"
}

variable scale_min  { 
  description = "Autoscale Min Number"
  type        = number
  default     = 2 
}

variable scale_max      {
  description = "Autoscale Max Number"
  type        = number 
  default     = 15
}

variable scale_desired  {
  description = "Autoscale Desired Number"
  type        = number
  default     = 2 
}

variable f5_username {
  description = "The admin username of the F5 Bigip that will be deployed"
  default     = "bigipuser"
}

variable RI_URL {
  description = "URL to download the BIG-IP Runtime Init Package"
  type        = string
  default     = "https://github.com/F5Networks/f5-bigip-runtime-init/releases/download/1.2.0/f5-bigip-runtime-init-1.2.0-1.gz.run"
}

# variable "aws_secretmanager_secret_id" {
#  description = "AWS Secret Manager Secret ID that stores the BIG-IP password"
#  type        = string
# }




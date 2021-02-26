# VPC
output "vpc_id" {
  value = module.vpc.vpc_id
}

# BIG-IP Autoscale Group ID
output "bigip_asg_id" {
  value = module.bigip.asg_id
}

# BIG-IP Autoscale Group Name
output "bigip_asg_name" {
  value = module.bigip.asg_name
}
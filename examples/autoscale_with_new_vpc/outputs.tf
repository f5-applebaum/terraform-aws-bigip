# VPC
output "vpc_id" {
  value = module.vpc.vpc_id
}

# # BIG-IP Autoscale Group Name
# output "bigip_asg_name" {
#   value = module.bigip.asg_name
# }

# # BIG-IP Autoscale Group ID
# output "bigip_asg_id" {
#   value = module.bigip.asg_id
# }

#
# NATIVE ASG MODULE
#
# BIG-IP Autoscale Group Name
output "bigip_asg_lc" {
  value = module.bigip_asg_module.this_autoscaling_group_name
}

output "bigip_asg_id" {
  value = module.bigip_asg_module.this_autoscaling_group_id
}

# BIG-IP Autoscale Group Launc Configuration ID
output "bigip_asg_name" {
  value = module.bigip_asg_module.this_launch_configuration_id
}


# BIG-IP NLB
output "nlb_dns_name" {
  value = module.nlb.this_lb_dns_name
}
# BIG-IP Management Public IP Addresses
#output "mgmt_public_ips" {
#  description = "List of BIG-IP public IP addresses for the management interfaces"
#  value       = aws_eip.mgmt[*].public_ip
#}

output "asg_id" { 
  value = aws_autoscaling_group.bigip_asg.id
}

output "asg_name" {
  value = aws_autoscaling_group.bigip_asg.name
}

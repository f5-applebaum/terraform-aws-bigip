output "asg_id" { 
  value = aws_autoscaling_group.bigip_asg.id
}

output "asg_name" {
  value = aws_autoscaling_group.bigip_asg.name
}

output "vpn_ip" {
  value       = (var.enable_eip ? aws_eip.wireguard_eip[0].public_ip : null)
  description = "The public IPv4 address of the AWS Elastic IP assigned to the instance."
}

output "vpn_sg_id" {
  value       = aws_security_group.sg_wireguard_admin.id
  description = "ID of the internal Security Group to associate with other resources needing to be accessed on VPN."
}

data "aws_ssm_parameter" "wg_server_private_key" {
  name = "/wireguard/server-private-key"
}


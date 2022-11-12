
data "aws_caller_identity" "self" {}

data "aws_region" "current" {}

data "aws_ami" "wireguard_ami_ubuntu_18" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-arm64-server-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "template_file" "user_data" {
  template = file("${path.module}/templates/user-data.tmpl")

  vars = {
    wg_server_private_key = data.aws_ssm_parameter.wg_server_private_key.value
    eip_id                = (var.enable_eip ? aws_eip.wireguard_eip[0].id : false)
    port                  = var.port
  }
}

data "aws_ssm_parameter" "wg_server_private_key" {
  name = "/wireguard/server-private-key"
}

data "template_cloudinit_config" "config" {
  part {
    content_type = "text/cloud-config"
    content      = data.template_file.user_data.rendered
  }
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "wireguard_policy_doc" {
  statement {
    actions = [
      "ec2:AssociateAddress",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "ssm:DescribeParameters"
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "ssm:GetParametersByPath"
    ]

    resources = ["arn:aws:ssm:*:${data.aws_caller_identity.self.account_id}:parameter/wireguard"]
  }
}

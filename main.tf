
data "aws_ami" "wireguard_ami_ubuntu_18" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
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
  template = file("${path.module}/templates/user-data.tpl")

  vars = {
    wg_server_private_key = data.aws_ssm_parameter.wg_server_private_key.value
    peers                 = join("\n", data.template_file.wg_client_data_json.*.rendered)
    eip_id                = aws_eip.wireguard_eip.id
  }
}

data "template_file" "wg_client_data_json" {
  template = file("${path.module}/templates/client-data.tpl")
  count    = length(var.wg_client_public_keys)

  vars = {
    client_pub_key = element(values(var.wg_client_public_keys[count.index]), 0)
    client_ip      = element(keys(var.wg_client_public_keys[count.index]), 0)
  }
}

data "template_cloudinit_config" "config" {
  part {
    content_type = "text/cloud-config"
    content      = data.template_file.user_data.rendered
  }
}

resource "aws_eip" "wireguard_eip" {
  vpc = true
}

resource "aws_launch_configuration" "wireguard_launch_config" {
  name_prefix                 = "${var.name}-wireguard-lc"
  image_id                    = data.aws_ami.wireguard_ami_ubuntu_18.id
  instance_type               = var.instance_size
  key_name                    = var.ssh_key_id
  iam_instance_profile        = aws_iam_instance_profile.wireguard_profile.name
  user_data                   = data.template_cloudinit_config.config.rendered
  security_groups             = [aws_security_group.sg_wireguard_external.id]
  associate_public_ip_address = true
  enable_monitoring           = false

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "wireguard_asg" {
  name_prefix          = "${var.name}-wireguard-asg"
  max_size             = 1
  min_size             = 1
  launch_configuration = aws_launch_configuration.wireguard_launch_config.name
  vpc_zone_identifier  = var.public_subnet_ids
  health_check_type    = "EC2"
  termination_policies = ["OldestInstance"]

  lifecycle {
    create_before_destroy = true
  }

  tags = [
    {
      key                 = "Name"
      value               = "${var.name}-wireguard-asg"
      propagate_at_launch = true
    },
    {
      key                 = "Terraform"
      value               = "true"
      propagate_at_launch = true
    },
  ]
}


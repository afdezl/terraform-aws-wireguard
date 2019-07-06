
locals {
  asg_min_instances = 0
  asg_max_instances = 1
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
  name                 = "${var.name}-wireguard-asg"
  max_size             = local.asg_max_instances
  min_size             = local.asg_min_instances
  desired_capacity     = 1
  launch_configuration = aws_launch_configuration.wireguard_launch_config.name
  vpc_zone_identifier  = var.public_subnet_ids
  health_check_type    = "EC2"
  termination_policies = ["OldestInstance"]

  lifecycle {
    create_before_destroy = true

    ignore_changes = [
      desired_capacity
    ]
  }

  tags = [
    {
      key                 = "Name"
      value               = "${var.name}-wireguard"
      propagate_at_launch = true
    },
    {
      key                 = "Terraform"
      value               = "true"
      propagate_at_launch = true
    },
  ]
}


resource "aws_autoscaling_policy" "scale_out" {
  name                   = "wireguard-start"
  scaling_adjustment     = 1
  adjustment_type        = "ExactCapacity"
  cooldown               = 240
  autoscaling_group_name = aws_autoscaling_group.wireguard_asg.name
}


resource "aws_autoscaling_policy" "scale_in" {
  name                   = "wireguard-stop"
  scaling_adjustment     = 0
  adjustment_type        = "ExactCapacity"
  cooldown               = 240
  autoscaling_group_name = aws_autoscaling_group.wireguard_asg.name
}

resource "aws_autoscaling_schedule" "nightly" {
  scheduled_action_name  = "nightly-shutdown"
  min_size               = local.asg_min_instances
  max_size               = local.asg_max_instances
  desired_capacity       = 0
  start_time             = formatdate("YYYY-MM-DD'T'02:00:00Z", timeadd(timestamp(), "24h"))
  recurrence             = "0 2 * * *"
  autoscaling_group_name = aws_autoscaling_group.wireguard_asg.name

  lifecycle {
    ignore_changes = [
      start_time
    ]
  }
}


resource "aws_iam_policy" "wireguard_policy" {
  name        = "${var.name}-wireguard"
  description = "Terraform Managed. Allows Wireguard instance to attach EIP."
  policy      = data.aws_iam_policy_document.wireguard_policy_doc.json
}


resource "aws_iam_role" "wireguard_role" {
  name               = "${var.name}-wireguard"
  description        = "Terraform Managed. Role to allow Wireguard instance to attach EIP."
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}


resource "aws_iam_role_policy_attachment" "wireguard_roleattach" {
  role       = aws_iam_role.wireguard_role.name
  policy_arn = aws_iam_policy.wireguard_policy.arn
}


resource "aws_iam_role_policy_attachment" "ssm_ec2_role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
  role       = aws_iam_role.wireguard_role.name
}


resource "aws_iam_instance_profile" "wireguard_profile" {
  name = "${var.name}-wireguard"
  role = aws_iam_role.wireguard_role.name
}


resource "aws_security_group" "sg_wireguard_external" {
  name        = "${var.name}-wireguard-external"
  description = "Terraform Managed. Allow Wireguard client traffic from internet."
  vpc_id      = var.vpc_id

  tags = var.tags

  ingress {
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "sg_wireguard_admin" {
  name        = "${var.name}-wireguard-admin"
  description = "Terraform Managed. Allow admin traffic to internal resources from VPN"
  vpc_id      = var.vpc_id

  tags = var.tags

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.sg_wireguard_external.id]
  }

  ingress {
    from_port       = 8
    to_port         = 0
    protocol        = "icmp"
    security_groups = [aws_security_group.sg_wireguard_external.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_ssm_parameter" "peers" {
  name  = "/wireguard/peers"
  type  = "SecureString"
  value = jsonencode(var.wg_clients)
}

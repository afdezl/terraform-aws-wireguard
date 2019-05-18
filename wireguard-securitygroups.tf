resource "aws_security_group" "sg_wireguard_external" {
  name        = "${var.name}-wireguard-external"
  description = "Terraform Managed. Allow Wireguard client traffic from internet."
  vpc_id      = "${var.vpc_id}"

  tags = "${var.tags}"

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
  vpc_id      = "${var.vpc_id}"

  tags = "${var.tags}"

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = ["${aws_security_group.sg_wireguard_external.id}"]
  }

  ingress {
    from_port       = 8
    to_port         = 0
    protocol        = "icmp"
    security_groups = ["${aws_security_group.sg_wireguard_external.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

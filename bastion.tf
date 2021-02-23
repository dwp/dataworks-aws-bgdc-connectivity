resource "aws_security_group" "win_bastion" {
  name        = "win-bastion"
  description = "Win Bastion SG"
  vpc_id      = module.vpc.vpc.id
  tags        = local.common_tags
}

resource "aws_security_group_rule" "win_outbound" {
  type              = "egress"
  protocol          = "tcp"
  from_port         = 0
  to_port           = 65535
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.win_bastion.id
}

resource "aws_security_group_rule" "win_outbound_dns" {
  type              = "egress"
  protocol          = "udp"
  from_port         = 53
  to_port           = 53
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.win_bastion.id
}

resource "aws_security_group_rule" "win_https" {
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = jsondecode(data.aws_secretsmanager_secret_version.bgdc_secret.secret_binary).bastion_ip_whitelist
  security_group_id = aws_security_group.win_bastion.id
}

resource "aws_security_group_rule" "win_rdp" {
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 3389
  to_port           = 3389
  cidr_blocks       = jsondecode(data.aws_secretsmanager_secret_version.bgdc_secret.secret_binary).bastion_ip_whitelist
  security_group_id = aws_security_group.win_bastion.id
}

resource "aws_security_group_rule" "win_8443" {
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 8443
  to_port           = 8443
  cidr_blocks       = jsondecode(data.aws_secretsmanager_secret_version.bgdc_secret.secret_binary).bastion_ip_whitelist
  security_group_id = aws_security_group.win_bastion.id
}

resource "aws_security_group_rule" "win_edc" {
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 9085
  to_port           = 9185
  cidr_blocks       = jsondecode(data.aws_secretsmanager_secret_version.bgdc_secret.secret_binary).bastion_ip_whitelist
  security_group_id = aws_security_group.win_bastion.id
}

resource "aws_security_group" "al2_bastion" {
  name        = "al2-bastion"
  description = "AL2 Bastion SG"
  vpc_id      = module.vpc.vpc.id
  tags        = local.common_tags
}

resource "aws_security_group_rule" "al2_outbound" {
  type              = "egress"
  protocol          = "tcp"
  from_port         = 0
  to_port           = 65535
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.al2_bastion.id
}

resource "aws_security_group_rule" "al2_outbound_dns" {
  type              = "egress"
  protocol          = "udp"
  from_port         = 53
  to_port           = 53
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.al2_bastion.id
}

resource "aws_security_group_rule" "al2_ssh" {
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_blocks       = jsondecode(data.aws_secretsmanager_secret_version.bgdc_secret.secret_binary).bastion_ip_whitelist
  security_group_id = aws_security_group.al2_bastion.id
}

data "aws_iam_policy_document" "bastion_assume_role_for_ssm" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "bastion" {
  name               = "bastion"
  assume_role_policy = data.aws_iam_policy_document.bastion_assume_role_for_ssm.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "bastion"
  role = aws_iam_role.bastion.name
}

resource "aws_instance" "win_bastion" {
  ami                    = local.win_bastion_ami_id
  instance_type          = "t2.medium"
  vpc_security_group_ids = [aws_security_group.win_bastion.id]
  subnet_id              = aws_subnet.public[0].id
  key_name               = local.informatica_key_pair_name
  iam_instance_profile   = aws_iam_instance_profile.bastion.id

  tags = merge(
    local.common_tags,
    {
      Name        = "bgdc-edc-bastion-windows",
      Persistence = "Ignore"
    },
  )
}

resource "aws_instance" "al2_bastion" {
  ami                    = local.al2_bastion_ami_id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.al2_bastion.id]
  subnet_id              = aws_subnet.public[0].id
  key_name               = local.informatica_key_pair_name
  iam_instance_profile   = aws_iam_instance_profile.bastion.id

  tags = merge(
    local.common_tags,
    {
      Name        = "bgdc-edc-bastion",
      Persistence = "Ignore"
    },
  )
}

resource "aws_eip" "win_bastion" {
  vpc = true
}

resource "aws_eip_association" "win_bastion" {
  instance_id   = aws_instance.win_bastion.id
  allocation_id = aws_eip.win_bastion.id
}

resource "aws_eip" "al2_bastion" {
  vpc = true
}

resource "aws_eip_association" "al2_bastion" {
  instance_id   = aws_instance.al2_bastion.id
  allocation_id = aws_eip.al2_bastion.id
}

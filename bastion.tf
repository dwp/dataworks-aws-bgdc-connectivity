resource "aws_security_group" "win_bastion" {
  name        = "win-bastion"
  description = "Win Bastion SG"
  vpc_id      = module.vpc.vpc.id
  tags        = local.common_tags
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

resource "aws_security_group_rule" "al2_ssh" {
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_blocks       = jsondecode(data.aws_secretsmanager_secret_version.bgdc_secret.secret_binary).bastion_ip_whitelist
  security_group_id = aws_security_group.al2_bastion.id
}

resource "aws_instance" "win_bastion" {
  ami                    = local.win_bastion_ami_id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.win_bastion.id]
  subnet_id              = aws_subnet.public[0].id
  key_name               = "bgdc-edc-key"

  tags = merge(
    local.common_tags,
    {
      Name = "bgdc-edc-bastion-windows"
    },
  )
}

resource "aws_instance" "al2_bastion" {
  ami                    = local.al2_bastion_ami_id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.al2_bastion.id]
  subnet_id              = aws_subnet.public[0].id

  tags = merge(
    local.common_tags,
    {
      Name = "bgdc-edc-bastion"
    },
  )
}

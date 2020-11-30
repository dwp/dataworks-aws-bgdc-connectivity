module "vpc" {
  source                                   = "dwp/vpc/aws"
  version                                  = "3.0.9"
  vpc_name                                 = local.bgdc_vpc_name
  region                                   = var.region
  vpc_cidr_block                           = lookup(local.cidr_block, local.environment).bgdc-edc-vpc
  gateway_vpce_route_table_ids             = [aws_route_table.public.id, aws_route_table.private.id, ]
  interface_vpce_source_security_group_ids = [aws_security_group.al2_bastion.id, aws_security_group.win_bastion.id]
  interface_vpce_subnet_ids                = [aws_subnet.private.0.id]
  common_tags                              = local.common_tags

  # cfnbootstrap has a bug where is's unable to talk to Cloudformation endpoint if internet access is also available
  aws_vpce_services = [
    "monitoring",
    "s3",
    "ssm",
    "ssmmessages",
    "ec2",
    "ec2messages",
    "kms",
    "secretsmanager",
    "elasticmapreduce",
    "logs",
    "autoscaling",
    #"cloudformation"
  ]
}

resource "aws_security_group_rule" "vpce" {
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = [module.vpc.vpc.cidr_block]
  security_group_id = module.vpc.interface_vpce_sg_id
}

resource "aws_subnet" "public" {
  count             = 2
  cidr_block        = cidrsubnet(module.vpc.vpc.cidr_block, 2, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = module.vpc.vpc.id

  tags = merge(
    local.common_tags,
    {
      Name = local.bgdc_subnet_names.public[count.index]
    },
  )
}

resource "aws_subnet" "private" {
  count             = 2
  cidr_block        = cidrsubnet(module.vpc.vpc.cidr_block, 2, length(aws_subnet.public) + count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = module.vpc.vpc.id

  tags = merge(
    local.common_tags,
    {
      Name = local.bgdc_subnet_names.private[count.index]
    },
  )
}

resource "aws_internet_gateway" "public" {
  vpc_id = module.vpc.vpc.id
  tags   = local.common_tags
}

resource "aws_nat_gateway" "public" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(
    local.common_tags,
    {
      Name = "bgdc-nat-gateway"
    },
  )
}

resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_route_table" "public" {
  vpc_id = module.vpc.vpc.id

  tags = merge(
    local.common_tags,
    {
      Name = "bgdc-edc-vpc-stackPublicRouteTable"
    },
  )
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.public.id
}

resource "aws_route_table" "private" {
  vpc_id = module.vpc.vpc.id

  tags = merge(
    local.common_tags,
    {
      Name = "bgdc-edc-vpc-stackPrivateRouteTable"
    },
  )
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.public)
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = aws_route_table.private.id
}

resource "aws_route" "private_internet" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.public.id
}

data "aws_vpc" "bgdc" {
  filter {
    name   = "tag:Name"
    values = [local.bgdc_vpc_name, ]
  }
}

resource "aws_vpc_peering_connection" "bgdc_to_internal_compute" {
  peer_vpc_id = data.terraform_remote_state.internal_compute.outputs.vpc.vpc.vpc.id
  vpc_id      = data.aws_vpc.bgdc.id
  auto_accept = true

  tags = merge(
    local.common_tags,
    {
      Name = "bgdc-to-internal-compute"
    },
    {
      Costcode = "PRJ0022507"
    },
  )
}

data "aws_route_table" "bgdc_private" {
  subnet_id = tolist(data.aws_subnet_ids.bgdc_private.ids)[0]
}

resource "aws_route" "bgdc_to_internal_compute" {
  count                     = length(data.terraform_remote_state.internal_compute.outputs.adg_subnet.ids)
  route_table_id            = data.aws_route_table.bgdc_private.id
  destination_cidr_block    = data.terraform_remote_state.internal_compute.outputs.adg_subnet.cidr_blocks[count.index]
  vpc_peering_connection_id = aws_vpc_peering_connection.bgdc_to_internal_compute.id
}

data "aws_route_table" "adg" {
  subnet_id = data.terraform_remote_state.internal_compute.outputs.adg_subnet.ids[0]
}

resource "aws_route" "adg_to_bgdc" {
  count                     = length(tolist(data.aws_subnet_ids.bgdc_private.ids))
  route_table_id            = data.aws_route_table.adg.id
  destination_cidr_block    = data.aws_subnet.bgdc_private[count.index].cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.bgdc_to_internal_compute.id
}

data "aws_network_acls" "bgdc_private" {
  vpc_id = data.aws_vpc.bgdc.id

  filter {
    name   = "tag:Name"
    values = ["bgdc-edc-vpc-stackPrivateNetworkAcl", ]
  }
}

resource "aws_network_acl_rule" "bgdc_to_hive_metastore" {
  network_acl_id = tolist(data.aws_network_acls.bgdc_private.ids)[0]
  rule_number    = 200
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 3306
  to_port        = 3306
}

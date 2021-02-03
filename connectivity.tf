resource "aws_vpc_peering_connection" "bgdc_to_internal_compute" {
  peer_vpc_id = data.terraform_remote_state.internal_compute.outputs.vpc.vpc.vpc.id
  vpc_id      = module.vpc.vpc.id
  auto_accept = true

  tags = merge(
    local.common_tags,
    {
      Name = "bgdc-to-internal-compute"
    },
  )

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "aws_route" "bgdc_to_internal_compute" {
  count                     = length(data.terraform_remote_state.internal_compute.outputs.bgdc_subnet.ids)
  route_table_id            = aws_route_table.private.id
  destination_cidr_block    = data.terraform_remote_state.internal_compute.outputs.bgdc_subnet.cidr_blocks[count.index]
  vpc_peering_connection_id = aws_vpc_peering_connection.bgdc_to_internal_compute.id
}

data "aws_route_table" "bgdc" {
  subnet_id = data.terraform_remote_state.internal_compute.outputs.bgdc_subnet.ids[0]
}

resource "aws_route" "bgdc_interface_to_bgdc" {
  count                     = length(aws_subnet.private)
  route_table_id            = data.aws_route_table.bgdc.id
  destination_cidr_block    = aws_subnet.private[count.index].cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.bgdc_to_internal_compute.id
}

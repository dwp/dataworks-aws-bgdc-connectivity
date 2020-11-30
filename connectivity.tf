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
}

resource "aws_route" "bgdc_to_internal_compute" {
  count                     = length(data.terraform_remote_state.internal_compute.outputs.pdm_subnet.ids)
  route_table_id            = aws_route_table.private.id
  destination_cidr_block    = data.terraform_remote_state.internal_compute.outputs.pdm_subnet.cidr_blocks[count.index]
  vpc_peering_connection_id = aws_vpc_peering_connection.bgdc_to_internal_compute.id
}

data "aws_route_table" "pdm" {
  subnet_id = data.terraform_remote_state.internal_compute.outputs.pdm_subnet.ids[0]
}

resource "aws_route" "pdm_to_bgdc" {
  count                     = length(aws_subnet.private)
  route_table_id            = data.aws_route_table.pdm.id
  destination_cidr_block    = aws_subnet.private[count.index].cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.bgdc_to_internal_compute.id
}

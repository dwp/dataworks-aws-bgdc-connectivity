data "aws_vpc" "bgdc" {
  filter {
    name   = "tag:Name"
    values = [local.bgdc_vpc_name, ]
  }
}

resource "aws_vpc_peering_connection" "bgdc_to_internal_compute" {
  peer_vpc_id = data.terraform_remote_state.internal_compute.outputs.vpc.vpc.vpc.id
  vpc_id      = data.aws_vpc.bgdc.id
  tags = local.common_tags
}

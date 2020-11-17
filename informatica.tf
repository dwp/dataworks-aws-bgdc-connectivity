locals {
  informatica_template_url      = "https://awsmp-fulfillment-cf-templates-prod.s3-external-1.amazonaws.com/dbbc4c44-2535-4eeb-a670-51110ee604a1-informatica-enterprise-data-catalog-existing-vpc-1041.template"
  informatica_key_pair_name     = "bgdc-edc-key"
  informatica_high_availability = "Disable"
  informatica_cluster_size      = "Small"
  informatica_deploy_bastion    = "No"
  secret_name                   = "/concourse/dataworks/bgdc"
  informatica_licence_key_url   = lookup(jsondecode(data.aws_secretsmanager_secret_version.bgdc_secret.secret_binary).informatica_licence_key_url, local.environment)
}

data "aws_secretsmanager_secret_version" "bgdc_secret" {
  provider  = aws.mgmt
  secret_id = local.secret_name
}

data "aws_subnet_ids" "bgdc_private" {
  vpc_id = data.aws_vpc.bgdc.id

  filter {
    name   = "tag:Name"
    values = ["bgdc-edc-vpc-stackPrivateSubnetA", "bgdc-edc-vpc-stackPrivateSubnetB"]
  }
}

data "aws_subnet" "bgdc_private" {
  count = length(tolist(data.aws_subnet_ids.bgdc_private.ids))
  id    = tolist(data.aws_subnet_ids.bgdc_private.ids)[count.index]
}

data "aws_security_group" "informatica_edc_infa_domain" {
  vpc_id = data.aws_vpc.bgdc.id

  filter {
    name   = "tag:aws:cloudformation:logical-id"
    values = ["InfaDomainEDCSecurityGroup", ]
  }

  depends_on = [aws_cloudformation_stack.informatica-edc]
}

data "aws_security_group" "informatica_edc_infa_additional" {
  vpc_id = data.aws_vpc.bgdc.id

  filter {
    name   = "tag:aws:cloudformation:logical-id"
    values = ["AdditionalEDCSecurityGroup", ]
  }

  depends_on = [aws_cloudformation_stack.informatica-edc]
}

resource "aws_security_group_rule" "edc_domain_to_hive" {
  description              = "Allow requests from BGDC Informatica EDC"
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = data.aws_security_group.informatica_edc_infa_domain.id
  security_group_id        = data.terraform_remote_state.analytical_dataset_gen.outputs.hive_metastore.security_group.id
}

resource "aws_security_group_rule" "edc_additional_to_hive" {
  description              = "Allow requests from BGDC Informatica EDC"
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = data.aws_security_group.informatica_edc_infa_additional.id
  security_group_id        = data.terraform_remote_state.analytical_dataset_gen.outputs.hive_metastore.security_group.id
}

resource "aws_cloudformation_stack" "informatica-edc" {
  name               = "informatica-edc"
  capabilities       = ["CAPABILITY_IAM"]
  template_url       = local.informatica_template_url
  timeout_in_minutes = 180

  timeouts {
    create = "3h"
    delete = "1h"
  }

  parameters = {
    VPC            = data.aws_vpc.bgdc.id
    Subnet1        = sort(tolist(data.aws_subnet_ids.bgdc_private.ids))[0]
    Subnet2        = sort(tolist(data.aws_subnet_ids.bgdc_private.ids))[1]
    IPAddressRange = data.aws_vpc.bgdc.cidr_block
    SubnetCheck    = "Yes"

    DeployBastionServer        = local.informatica_deploy_bastion
    BastionSubnet              = sort(tolist(data.aws_subnet_ids.bgdc_private.ids))[0]
    KeyPairName                = local.informatica_key_pair_name
    InformaticaLicenseKeyS3URI = local.informatica_licence_key_url
    InfaHA                     = local.informatica_high_availability
    IHSClusterSize             = local.informatica_cluster_size
  }

}

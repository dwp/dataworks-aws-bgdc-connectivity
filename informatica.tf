locals {
  informatica_template_url      = "https://awsmp-fulfillment-cf-templates-prod.s3-external-1.amazonaws.com/dbbc4c44-2535-4eeb-a670-51110ee604a1-informatica-enterprise-data-catalog-existing-vpc-1041.template"
  informatica_key_pair_name     = "bgdc2"
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


# EDC security group rules have to be injected AFTER aws_cloudformation_stack.informatica-edc have been updated
# this could be achieved with 'depends_on' but the downside is 'terraform plan' always showing changes
# Using a spoof edc_dependency variable allows to avoid this
locals {
  edc_dependency = substr(aws_cloudformation_stack.informatica-edc.id, 62, 43)
}

data "aws_security_group" "informatica_edc_infa_domain" {
  vpc_id = module.vpc.vpc.id

  filter {
    name   = "tag:aws:cloudformation:logical-id"
    values = ["InfaDomainEDCSecurityGroup", local.edc_dependency]
  }
}

data "aws_security_group" "informatica_edc_infa_additional" {
  vpc_id = module.vpc.vpc.id

  filter {
    name   = "tag:aws:cloudformation:logical-id"
    values = ["AdditionalEDCSecurityGroup", local.edc_dependency]
  }
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

resource "aws_security_group_rule" "vpce_from_domain" {
  description              = "Allow requests from BGDC Informatica EDC"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = data.aws_security_group.informatica_edc_infa_domain.id
  security_group_id        = module.vpc.interface_vpce_sg_id
}

resource "aws_security_group_rule" "vpce_from_additional" {
  description              = "Allow requests from BGDC Informatica EDC"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = data.aws_security_group.informatica_edc_infa_additional.id
  security_group_id        = module.vpc.interface_vpce_sg_id
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
    VPC            = module.vpc.vpc.id
    Subnet1        = aws_subnet.private[0].id
    Subnet2        = aws_subnet.private[1].id
    IPAddressRange = module.vpc.vpc.cidr_block
    SubnetCheck    = "Yes"

    DeployBastionServer        = local.informatica_deploy_bastion
    BastionSubnet              = aws_subnet.private[0].id
    KeyPairName                = local.informatica_key_pair_name
    InformaticaLicenseKeyS3URI = local.informatica_licence_key_url
    InfaHA                     = local.informatica_high_availability
    IHSClusterSize             = local.informatica_cluster_size
  }

}

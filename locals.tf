locals {

  bgdc_vpc_name = "bgdc-edc-vpc-stack-vpc"

  bgdc_subnet_names = {
    public  = ["bgdc-edc-vpc-stackPublicSubnetA", "stackPublicSubnetB", ]
    private = ["bgdc-edc-vpc-stackPrivateSubnetA", "bgdc-edc-vpc-stackPrivateSubnetB", ]
  }

  management_account = {
    development = "management-dev"
    qa          = "management-dev"
    integration = "management-dev"
    preprod     = "management"
    production  = "management"
  }

  win_bastion_ami_id = "ami-05dcd4060b959959b"
  al2_bastion_ami_id = "ami-0a669382ea0feb73a"
}

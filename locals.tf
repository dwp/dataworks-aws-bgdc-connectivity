locals {

  bgdc_vpc_name = "bgdc-edc-vpc-stack-vpc"

  management_account = {
    development = "management-dev"
    qa          = "management-dev"
    integration = "management-dev"
    preprod     = "management"
    production  = "management"
  }
}

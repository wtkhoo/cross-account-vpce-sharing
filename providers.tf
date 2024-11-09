provider "aws" {
  alias  = "hub"
}

provider "aws" {
  alias  = "spoke"
  assume_role {
    role_arn    = data.terraform_remote_state.terraform_service_role.outputs.terraform_role_arn
    external_id = data.terraform_remote_state.terraform_service_role.outputs.sts_external_id
  }
}

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "5.36.0"
    }
  }
}

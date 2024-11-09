
# Retrieve output values from another Terraform state
data "terraform_remote_state" "terraform_service_role" {
  backend = "local"

  config = {
    path = "${path.module}/../terraform-service-role/terraform.tfstate"
  }
}
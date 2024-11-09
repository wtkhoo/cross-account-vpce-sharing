# Cross-acount SSM VPC endpoints sharing demo environment

## Overview

This folder contains the Terraform code to deploy AWS demo environment to demonstrate cross-account sharing of SSM VPC interface endpoints. For more details, read my [blog post](https://blog.wkhoo.com/posts/cross-account-vpce-sharing/).

A high level architecture diagram of the demo environment:

![Demo architecture](https://blog.wkhoo.com/images/cross-account-vpce-demo-architecture_hu2e8c7672d23440c7629df7715571b680_138199_800x640_fit_q50_box.jpeg)

> **Important note:** Deploying this demo environment will incur some cost in your AWS accounts because of the SSM VPC endpoint hours and the associated data transfer charges.

## Requirements

- [Terraform](https://www.terraform.io/downloads) (>= 1.5.0)
- 2x AWS account [configured with proper credentials to run Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration)

## Pre-requisites

An IAM assume role needs to be created separately on the spoke AWS account as Terraform service role. Refer to the README on this [GitHub repo](https://github.com/wtkhoo/terraform-service-role) to deploy the IAM role first before deploying this Terraform code.

## Walkthrough

1) Clone this repository to your local machine.

   ```shell
   git clone https://github.com/wtkhoo/cross-acount-vpce-sharing.git
   ```

2) Change your directory to the `cross-account-vpce-sharing` folder.

   ```shell
   cd cross-account-vpce-sharing
   ```

3) Run the terraform [init](https://www.terraform.io/cli/commands/init) command to initialize the Terraform deployment and set up the providers.

   ```shell
   terraform init
   ```

4) To customize your deployment, create a `terraform.tfvars` file and specify your values.

   ```
   # Prefix name for resources
   name     = "ssm-demo"
   # Hub VPC CIDR block
   hub_vpc_cidr = "10.0.0.0/16"
   # Spoke VPC CIDR block
   spoke_vpc_cidr = "10.1.0.0/16"
   ```
  
5) Next step is to run a terraform [plan](https://www.terraform.io/cli/commands/plan) command to preview what will be created.

   ```shell
   terraform plan
   ```

6) If your values are valid, you're ready to go. Run the terraform [apply](https://www.terraform.io/cli/commands/apply) command to provision the resources.

   ```shell
   terraform apply
   ```

7) When you're done with the demo, run the terraform [destroy](https://www.terraform.io/cli/commands/destroy) command to delete all resources that were created in your AWS environment.

   ```shell
   terraform destroy
   ```

## Questions and Feedback

If you have any questions or feedback, please don't hesitate to [create an issue](https://github.com/wtkhoo/cross-account-vpce-sharing/issues/new).
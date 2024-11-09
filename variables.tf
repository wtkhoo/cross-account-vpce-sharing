variable "name" {
  description = "Prefix name for resources"
  type        = string
  default     = "ssm-demo"
}

variable "hub_vpc_cidr" {
  description = "Hub VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "spoke_vpc_cidr" {
  description = "Spoke VPC CIDR block"
  type        = string
  default     = "10.1.0.0/16"
}
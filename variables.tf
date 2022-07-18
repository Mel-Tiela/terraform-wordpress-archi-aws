variable "cidr_block" {
  type        = string
  description = "VPC cidr block."
}

variable "availability_zones" {
  type = list(string)
}

variable "environment" {
  type = list(string)
  description = "The environment which to fetch the configuration for."
}

variable "instance_type" {
  type = string
}

variable "key_name" {
  type = string
}

variable "workstation_ip" {
  type = string
}

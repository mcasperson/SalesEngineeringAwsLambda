terraform {
  backend "s3" {
  }
}

variable "octopus_server" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The URL of the Octopus server e.g. https://myinstance.octopus.app."
}

variable "octopus_apikey" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "The API key used to access the Octopus server. See https://octopus.com/docs/octopus-rest-api/how-to-create-an-api-key for details on creating an API key."
}

variable "octopus_space_id" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The ID of the Octopus space to populate."
}

variable "account_aws_account" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "The AWS secret key associated with the account AWS Account"
}

variable "account_aws_account_access" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "The AWS access key associated with the account AWS Account"
}

module "octopus" {
  source = "../octopus"
  octopus_server = var.octopus_server
  octopus_apikey = var.octopus_apikey
  octopus_space_id = var.octopus_space_id
  account_aws_account = var.account_aws_account
  account_aws_account_access = var.account_aws_account_access
}
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" 
    }
  }
}

# This empty provider block tells the module to expect 
# a provider configuration with the alias 'us-east-1' 
# to be passed from the parent module (the root main.tf).
provider "aws" {
  alias = "us-east-1"
}
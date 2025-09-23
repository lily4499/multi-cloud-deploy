terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~>5.0"
    }
  }
}


provider "aws" {
  region = "us-east-1"
}

provider "azurerm" {
  features {}
}

provider "google" {
  project = "x-object-472022-q2"
  region  = "us-east4"
}
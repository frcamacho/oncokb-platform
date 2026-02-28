terraform {
  backend "s3" {
    bucket               = "oncokb-tfstate-473e7965"
    key                  = "oncokb-platform/terraform.tfstate"
    region               = "us-east-1"
    dynamodb_table       = "oncokb-terraform-locks"
    encrypt              = true
    workspace_key_prefix = "workspaces"
  }
}

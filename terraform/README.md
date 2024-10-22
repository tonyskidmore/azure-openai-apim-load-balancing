# Terraform

Terraform version on the Bicep `infra/` code.  Update `terraform.tfvars` before running.

````bash

# using local backend
terraform init
terraform validate
terraform plan -out tfplan
terraform apply tfplan

````

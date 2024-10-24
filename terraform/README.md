# Terraform

Terraform version on the Bicep `infra/` code.  Update `terraform.tfvars` before running.

````bash

# using local backend
terraform init
terraform validate
terraform plan -out tfplan
terraform apply tfplan

````

## Python testing

Added Python testing script, including option for outbound headers.
When using the `round-robin-policy-with-outbound.xml` policy file.

Update values in `python/.env` using `.env.sample` as a template.

Example Python virtual environment creation for executing `main.py`:

````bash

cd python
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python3 main.py

````

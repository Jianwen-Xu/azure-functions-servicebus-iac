.PHONY: help init fmt fmt-check validate lint plan apply destroy clean bootstrap

TF      ?= terraform
ENV     ?= dev
TFVARS  := -var-file=envs/$(ENV).tfvars
BACKEND := -backend-config=envs/$(ENV).backend.hcl

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

init: ## Initialise the working directory for ENV (default: dev)
	$(TF) init $(BACKEND) -input=false

fmt: ## Rewrite all Terraform files to canonical format
	$(TF) fmt -recursive

validate: fmt ## Format, validate the root and the bootstrap module
	$(TF) validate -no-color
	cd bootstrap && $(TF) init -backend=false -input=false >/dev/null && $(TF) validate -no-color

lint: ## Run tflint across every module
	tflint --init && tflint --recursive

plan: ## Show the plan for ENV
	$(TF) plan $(TFVARS) -input=false -out=tfplan

apply: ## Apply the last plan for ENV
	$(TF) apply -input=false tfplan

destroy: ## Destroy ENV (asks for confirmation)
	$(TF) destroy $(TFVARS)

clean: ## Remove local Terraform working files
	rm -rf .terraform .terraform.lock.hcl tfplan plan.txt
	find . -name '.terraform' -type d -prune -exec rm -rf {} +

fmt-check: ## Fail if anything is unformatted (what CI runs)
	$(TF) fmt -check -recursive -diff

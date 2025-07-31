.PHONY: docs
docs:
	@cd scripts && bash generate-docs.sh

.PHONY: format
format:
	@echo "Formatting terraform"
	@terraform fmt -recursive

.PHONY: test
test:
	@make tfsec
	@make tftest-gcp

.PHONY: tfsec
tfsec:
	@tfsec .

.PHONY: tftest-gcp
tftest-gcp:
	@export GOOGLE_PROJECT="dummy-project" GOOGLE_CREDENTIALS='{"type": "service_account"}'
	@cd nomad-gcp && terraform init -backend=false && terraform test
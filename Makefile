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

.PHONY: tfsec
tfsec:
	@tfsec .

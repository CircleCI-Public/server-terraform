.PHONY: docs
docs:
	@cd scripts && bash generate-docs.sh

.PHONY: format
format:
	@echo "Formatting terraform"
	@terraform fmt -recursive

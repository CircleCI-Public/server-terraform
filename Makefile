.PHONY: install
install:
	@echo "Configuring pre-commit for local module development"
	@cd nomad-aws && pre-commit install
	@cd nomad-gcp && pre-commit install
	@cd shared/modules/tls && pre-commit install

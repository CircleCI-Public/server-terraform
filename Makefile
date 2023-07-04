.PHONY: install
install:
	@echo "Configuring pre-commit for local module development"
	@pre-commit install
	
.PHONY: install-deps-osx
install-deps-osx:
	@brew install pre-commit terraform-docs

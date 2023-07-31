#!/bin/bash
# Generates readmes for terraform modules using terraform-docs

function check_terraform_docs_exists() {
    if ! command -v terraform-docs &> /dev/null; then
        echo "The terraform-docs CLI tool must be installed to continue"
        exit 1;
    fi;
}

function run_terraform_docs() {
    script_dir=$(realpath "$(dirname "$0")")
    terraform-docs markdown table --output-file "$script_dir/$1" --output-mode inject "$2"
}

check_terraform_docs_exists
echo "Autogenerating terraform docs"
run_terraform_docs "../nomad-aws/README.md" "../nomad-aws/"
run_terraform_docs "../nomad-gcp/README.md" "../nomad-gcp/"
echo "Docs generation complete"

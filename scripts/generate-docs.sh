#!/usr/bin/env bash
# Generates READMEs for Terraform modules using terraform-docs

set -eu -o pipefail

TERRAFORM_DOCS_VERSION=0.20.0

function run_terraform_docs() {
    script_dir=$(realpath "$(dirname "$0")")
    parent_dir=$(dirname "$script_dir")
    output_file="${1#../}"
    input_dir="${2#../}"
    docker run --rm --volume "$parent_dir:/terraform-docs" -u "$(id -u)" \
      quay.io/terraform-docs/terraform-docs:"$TERRAFORM_DOCS_VERSION" markdown table \
      --output-file "/terraform-docs/$output_file" \
      --output-mode inject "/terraform-docs/$input_dir"
}

echo "Auto-generating Terraform docs"
run_terraform_docs "../nomad-aws/README.md" "../nomad-aws/"
run_terraform_docs "../nomad-gcp/README.md" "../nomad-gcp/"
echo "Docs generation complete"

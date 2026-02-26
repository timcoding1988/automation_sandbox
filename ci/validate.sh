#!/bin/bash

# Validation script for CI
# Validates Packer templates

set -eo pipefail

SCRIPT_DIRPATH=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
REPO_DIRPATH=$(realpath "$SCRIPT_DIRPATH/..")

echo "=== Validating Packer Templates ==="

cd "$REPO_DIRPATH"

# Check if packer is installed
if ! command -v packer &>/dev/null; then
    echo "ERROR: packer is not installed"
    exit 1
fi

# Initialize and validate each Packer directory
for dir in packer/*/; do
    # Find the main HCL file
    if ls "${dir}"*.pkr.hcl &>/dev/null; then
        echo "Validating ${dir}..."

        # Initialize plugins
        packer init "${dir}"

        # Validate with dummy values for required variables
        packer validate \
            -var "compartment_ocid=ocid1.compartment.oc1..dummy" \
            -var "subnet_ocid=ocid1.subnet.oc1..dummy" \
            -var "availability_domain=AD-1" \
            -var "base_image_ocid=ocid1.image.oc1..dummy" \
            "${dir}"

        echo "  OK"
    fi
done

echo "=== All Packer templates valid ==="

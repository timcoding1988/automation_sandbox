#!/bin/bash

# Base image setup script for Fedora on OCI
# Creates a minimal Fedora image with cloud-init for OCI

set -eo pipefail

SCRIPT_FILEPATH=$(realpath "${BASH_SOURCE[0]}")
SCRIPT_DIRPATH=$(dirname "$SCRIPT_FILEPATH")
REPO_DIRPATH=$(realpath "$SCRIPT_DIRPATH/../../../")

echo "=== Fedora Base Image Setup ==="
echo "Script: $SCRIPT_FILEPATH"
echo "Repo: $REPO_DIRPATH"

# Run systemd banish to disable unnecessary services
if [[ -r "$REPO_DIRPATH/systemd_banish.sh" ]]; then
    /bin/bash "$REPO_DIRPATH/systemd_banish.sh" || true
fi

# Source library
if [[ -r "$REPO_DIRPATH/lib.sh" ]]; then
    # shellcheck source=../../../lib.sh
    source "$REPO_DIRPATH/lib.sh"
fi

echo "=== Configuring DNF for reliable downloads ==="
cat << EOF | tee -a /etc/dnf/dnf.conf

# Added during CI VM image build
minrate=100
timeout=60
EOF

echo "=== Updating system packages ==="
dnf makecache
dnf -y update

echo "=== Installing base packages ==="
declare -a PKGS=(
    rng-tools
    git
    coreutils
    cloud-init
    cloud-utils-growpart
    curl
    vim
    bash-completion
)

dnf -y install "${PKGS[@]}"

# Run any remaining updates
dnf -y update

echo "=== Enabling services ==="
systemctl enable rngd || true
systemctl enable cloud-init || true
systemctl enable cloud-init-local || true
systemctl enable cloud-config || true
systemctl enable cloud-final || true

echo "=== Configuring cloud-init for OCI ==="
# Configure cloud-init datasource for OCI
cat > /etc/cloud/cloud.cfg.d/99_oci.cfg <<EOF
# OCI-specific cloud-init configuration
datasource_list: [ Oracle, None ]
datasource:
  Oracle:
    configure_secondary_nics: true
EOF

# Ensure cloud-init runs on every boot for user-data
cat > /etc/cloud/cloud.cfg.d/99_preserve_hostname.cfg <<EOF
preserve_hostname: false
EOF

echo "=== Installing automation tooling ==="
if type -t install_automation_tooling &>/dev/null; then
    install_automation_tooling
else
    echo "Automation tooling function not available, skipping"
fi

echo "=== Finalizing image ==="
if type -t finalize &>/dev/null; then
    finalize
else
    echo "Finalize function not available, running basic cleanup"
    # Basic cleanup
    cloud-init clean --logs 2>/dev/null || true
    rm -rf /var/lib/cloud/instance*
    rm -rf /root/.ssh/*
    rm -rf /etc/ssh/*key*
    rm -rf /tmp/*
    echo -n "" > /etc/machine-id
    sync
    fstrim -av 2>/dev/null || true
fi

echo "=== Fedora Base Image Setup Complete ==="

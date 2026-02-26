#!/bin/bash

# Bootstrap script for image-builder VM
# Installs tools needed for building other images: Packer, QEMU/KVM, OCI CLI, Podman

set -eo pipefail

SCRIPT_FILEPATH=$(realpath "${BASH_SOURCE[0]}")
SCRIPT_DIRPATH=$(dirname "$SCRIPT_FILEPATH")
REPO_DIRPATH=$(realpath "$SCRIPT_DIRPATH/../../../")

echo "=== Image Builder Bootstrap ==="
echo "Script: $SCRIPT_FILEPATH"
echo "Repo: $REPO_DIRPATH"

# Source library if available
if [[ -r "$REPO_DIRPATH/lib.sh" ]]; then
    # shellcheck source=../../../lib.sh
    source "$REPO_DIRPATH/lib.sh"
fi

# Run systemd banish script to disable unnecessary services
if [[ -r "$REPO_DIRPATH/systemd_banish.sh" ]]; then
    /bin/bash "$REPO_DIRPATH/systemd_banish.sh" || true
fi

echo "=== Updating system packages ==="
dnf update -y

echo "=== Installing EPEL repository ==="
dnf install -y oracle-epel-release-el8 || dnf install -y epel-release || true

echo "=== Installing required packages ==="
dnf install -y \
    bash-completion \
    buildah \
    curl \
    findutils \
    gawk \
    genisoimage \
    git \
    jq \
    libvirt \
    libvirt-client \
    libvirt-daemon \
    libvirt-daemon-kvm \
    make \
    openssh \
    openssl \
    podman \
    python3 \
    python3-pip \
    qemu-img \
    qemu-kvm \
    rng-tools \
    rsync \
    sed \
    skopeo \
    tar \
    unzip \
    util-linux \
    vim \
    wget

echo "=== Installing OCI CLI ==="
# Install OCI CLI via pip
pip3 install oci-cli --quiet

echo "=== Installing Packer ==="
PACKER_VERSION="${PACKER_VERSION:-1.10.0}"
PACKER_URL="https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip"
cd /tmp
curl -fsSL -o packer.zip "$PACKER_URL"
unzip -o packer.zip -d /usr/local/bin/
rm -f packer.zip
packer --version

echo "=== Enabling nested virtualization ==="
# Enable nested virtualization for KVM
cat > /etc/modprobe.d/kvm-nested.conf <<EOF
options kvm-intel nested=1
options kvm-intel enable_shadow_vmcs=1
options kvm-intel enable_apicv=1
options kvm-intel ept=1
options kvm-amd nested=1
EOF

echo "=== Enabling services ==="
systemctl enable libvirtd || true
systemctl enable rngd || true

echo "=== Installing automation tooling ==="
# Install containers/automation library if function is available
if type -t install_automation_tooling &>/dev/null; then
    install_automation_tooling
else
    echo "Automation tooling function not available, skipping"
fi

echo "=== Finalizing image ==="
# Run finalize if available
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

echo "=== Image Builder Bootstrap Complete ==="

#!/bin/bash

# Cache image setup script for Fedora on OCI
# Creates a CI-ready Fedora image with all build/test dependencies

set -eo pipefail

SCRIPT_FILEPATH=$(realpath "${BASH_SOURCE[0]}")
SCRIPT_DIRPATH=$(dirname "$SCRIPT_FILEPATH")
REPO_DIRPATH=$(realpath "$SCRIPT_DIRPATH/../../../")

echo "=== Fedora Cache Image Setup ==="
echo "Script: $SCRIPT_FILEPATH"
echo "Repo: $REPO_DIRPATH"

# Source library
if [[ -r "$REPO_DIRPATH/lib.sh" ]]; then
    # shellcheck source=../../../lib.sh
    source "$REPO_DIRPATH/lib.sh"
fi

# Run systemd banish to disable unnecessary services
if [[ -r "$REPO_DIRPATH/systemd_banish.sh" ]]; then
    /bin/bash "$REPO_DIRPATH/systemd_banish.sh" || true
fi

echo "=== Configuring /tmp tmpfs size ==="
# Make /tmp tmpfs bigger for tests (75% of RAM)
mkdir -p /etc/systemd/system/tmp.mount.d
echo -e "[Mount]\nOptions=size=75%%,mode=1777\n" > /etc/systemd/system/tmp.mount.d/override.conf

echo "=== Updating system packages ==="
dnf update -y

echo "=== Installing CI/CD packages ==="

# Core packages for container development and testing
INSTALL_PACKAGES=(
    # Build tools
    autoconf
    automake
    gcc
    git
    make
    libtool
    pkgconfig
    redhat-rpm-config

    # Container tools
    buildah
    catatonit
    conmon
    containernetworking-plugins
    containers-common
    criu
    crun
    fuse-overlayfs
    passt
    podman
    podman-remote
    runc
    skopeo
    slirp4netns

    # Development libraries
    btrfs-progs-devel
    device-mapper-devel
    e2fsprogs-devel
    fuse3-devel
    glib2-devel
    glibc-devel
    glibc-static
    gpgme-devel
    libassuan-devel
    libblkid-devel
    libcap-devel
    libffi-devel
    libgpg-error-devel
    libnet-devel
    libnl3-devel
    libseccomp-devel
    libselinux-devel
    libxml2-devel
    libxslt-devel
    openssl-devel
    ostree-devel
    protobuf-c-devel
    protobuf-devel
    sqlite-devel
    zlib-devel

    # Test tools
    bats
    ShellCheck
    pre-commit

    # Go toolchain
    golang
    go-md2man

    # Python tools
    python3
    python3-devel
    python3-pip
    python3-PyYAML
    python3-requests

    # Utilities
    bash-completion
    bzip2
    curl
    dnsmasq
    emacs-nox
    file
    findutils
    fuse3
    gnupg
    hostname
    httpd-tools
    iproute
    iptables
    jq
    lsof
    man-db
    nfs-utils
    nmap-ncat
    openssl
    pandoc
    parallel
    pigz
    procps-ng
    rsync
    sed
    socat
    squashfs-tools
    tar
    time
    unzip
    vim
    wget
    which
    xz
    zip
    zstd

    # SELinux tools
    container-selinux
    policycoreutils
    selinux-policy-devel
)

dnf install -y "${INSTALL_PACKAGES[@]}"

echo "=== Configuring container SELinux ==="
setsebool -P container_manage_cgroup true || true

echo "=== Configuring NetworkManager for CNI ==="
# Prevent NetworkManager from interfering with container networking
mkdir -p /etc/NetworkManager/conf.d/
cat > /etc/NetworkManager/conf.d/podman-cni.conf <<EOF
[keyfile]
unmanaged-devices=interface-name:*podman*;interface-name:veth*
EOF

echo "=== Running final updates ==="
dnf update -y

echo "=== Finalizing image ==="
if type -t finalize &>/dev/null; then
    finalize
else
    echo "Finalize function not available, running basic cleanup"
    cloud-init clean --logs 2>/dev/null || true
    rm -rf /var/lib/cloud/instance*
    rm -rf /root/.ssh/*
    rm -rf /etc/ssh/*key*
    rm -rf /tmp/*
    echo -n "" > /etc/machine-id
    sync
    fstrim -av 2>/dev/null || true
fi

echo "=== Fedora Cache Image Setup Complete ==="
echo "SUCCESS!"

#!/bin/bash

# Shared shell functions for OCI image building
# Sourced by other scripts during VM image creation

# By default, assume we're not running inside a container
CONTAINER="${CONTAINER:-0}"

# OS detection
OS_RELEASE_VER="$(source /etc/os-release 2>/dev/null && echo $VERSION_ID | tr -d '.')"
OS_RELEASE_ID="$(source /etc/os-release 2>/dev/null && echo $ID)"
OS_REL_VER="${OS_RELEASE_ID:-unknown}-${OS_RELEASE_VER:-unknown}"

# Avoid getting stuck waiting for user input
[[ "$OS_RELEASE_ID" != "debian" ]] || \
    export DEBIAN_FRONTEND="noninteractive"

# Package download cache location
PACKAGE_DOWNLOAD_DIR=/var/cache/download

# Automation library version (managed by renovate)
INSTALL_AUTOMATION_VERSION="5.0.1"

# Mask secrets in show_env_vars()
SECRET_ENV_RE='(^PATH$)|(^BASH_FUNC)|(^_.*)|(.*PASSWORD.*)|(.*TOKEN.*)|(.*SECRET.*)|(.*ACCOUNT.*)|(.+_JSON)|(OCI.+)|(.*SSH.*)|(.*KEY.*)'

# Simple error handling when automation library is not available
die() { echo "ERROR: ${1:-No error message provided}" >&2; exit 1; }

# Check if automation library is installed
if [[ -r "/etc/automation_environment" ]]; then
    source /etc/automation_environment
    #shellcheck disable=SC1090,SC2154
    source "$AUTOMATION_LIB_PATH/common_lib.sh"
    lilto() { err_retry 8 1000 "" "$@"; }  # ~4 minutes max
    bigto() { err_retry 7 5670 "" "$@"; }  # 12 minutes max
else
    echo "Warning: Automation library not found"
    lilto() { die "Automation library required for lilto()"; }
    bigto() { die "Automation library required for bigto()"; }
fi

# Set up sudo with noninteractive mode
export SUDO="env DEBIAN_FRONTEND=noninteractive"
if [[ "$UID" -ne 0 ]]; then
    export SUDO="sudo env DEBIAN_FRONTEND=noninteractive"
fi

# Install automation tooling from containers/automation repo
install_automation_tooling() {
    local version_arg="$INSTALL_AUTOMATION_VERSION"

    if [[ "$1" == "latest" ]]; then
        version_arg="latest"
        shift
    fi

    local installer_url="https://raw.githubusercontent.com/containers/automation/master/bin/install_automation.sh"
    curl --silent --show-error --location \
         --url "$installer_url" | \
         $SUDO env INSTALL_PREFIX=/usr/share /bin/bash -s - \
        "$version_arg" "$@"
    source /usr/share/automation/environment
    #shellcheck disable=SC1090
    source "$AUTOMATION_LIB_PATH/common_lib.sh"
}

# Clean up credential files on exit
clear_cred_files() {
    set +ex
    if [[ -n "${OCI_KEY_FILE:-}" ]] && [[ -f "$OCI_KEY_FILE" ]]; then
        rm -f "$OCI_KEY_FILE"
    fi
}

# Set up OCI credentials from environment (for CI use)
set_oci_credentials() {
    if [[ -z "${CI:-}" ]] || [[ "$CI" != "true" ]]; then
        die "set_oci_credentials() only works under CI"
    fi

    # Check required OCI environment variables
    for var in OCI_TENANCY_OCID OCI_USER_OCID OCI_FINGERPRINT OCI_REGION; do
        if [[ -z "${!var:-}" ]]; then
            die "Required \$$var is not set"
        fi
    done

    if [[ -z "${OCI_PRIVATE_KEY:-}" ]]; then
        die "Required \$OCI_PRIVATE_KEY is not set"
    fi

    set +x
    OCI_KEY_FILE=$(mktemp -p '' '.oci_key.XXXXXXXX')
    export OCI_KEY_FILE
    trap clear_cred_files EXIT
    echo "$OCI_PRIVATE_KEY" > "$OCI_KEY_FILE"
    chmod 600 "$OCI_KEY_FILE"
    unset OCI_PRIVATE_KEY
}

# Clean up automatic users created by cloud-init or packer
clean_automatic_users() {
    local DELUSER="userdel --remove"
    local DELGROUP="groupdel"

    if [[ "$OS_RELEASE_ID" == "debian" ]]; then
        DELUSER="deluser --remove-home"
        DELGROUP="delgroup --only-if-empty"
    fi

    cd /home || exit
    for account in *; do
        if id "$account" &> /dev/null && [[ "$account" != "$USER" ]]; then
            $SUDO $DELUSER "$account" || true
            $SUDO $DELGROUP "$account" 2>/dev/null || true
        fi
    done
    $SUDO rm -rf /home/*/.ssh/*
}

# NetworkManager workaround for container networking
nm_ignore_cni() {
    echo "Deploying NetworkManager CNI workaround"
    $SUDO mkdir -p /etc/NetworkManager/conf.d/
    cat << EOF | $SUDO tee /etc/NetworkManager/conf.d/podman-cni.conf
[keyfile]
unmanaged-devices=interface-name:*podman*;interface-name:veth*
EOF
}

# Common finalization steps for all images
common_finalize() {
    set -x
    cd /
    clean_automatic_users
    $SUDO cloud-init clean --logs 2>/dev/null || true
    if ! ((CONTAINER)); then
        bash "$(dirname "${BASH_SOURCE[0]}")/systemd_banish.sh" 2>/dev/null || true
    fi
    $SUDO rm -rf /var/lib/cloud/instanc*
    $SUDO rm -rf /root/.ssh/*
    $SUDO rm -rf /etc/ssh/*key*
    $SUDO rm -rf /tmp/* /var/tmp/automation_images
    $SUDO rm -rf /tmp/.??*
    echo -n "" | $SUDO tee /etc/machine-id
    $SUDO sync
    if ! ((CONTAINER)); then
        $SUDO fstrim -av 2>/dev/null || true
    fi
}

# Finalize Red Hat-based images (Fedora, CentOS)
rh_finalize() {
    set +e
    if ((CONTAINER)); then
        echo "Cleaning up packaging metadata and cache"
        $SUDO dnf clean all
        $SUDO rm -rf /var/cache/dnf
    fi
    set -x
    $SUDO rm -f /etc/udev/rules.d/*-persistent-*.rules
    $SUDO touch /.unconfigured

    echo
    echo "# PACKAGE LIST"
    rpm -qa | sort
}

# Finalize Debian-based images
debian_finalize() {
    set +e
    if ((CONTAINER)); then
        echo "Cleaning up packaging metadata and cache"
        $SUDO apt-get clean
        $SUDO rm -rf /var/cache/apt
    fi
    set -x
    echo "# PACKAGE LIST"
    dpkg -l | cat
}

# Main finalize function - dispatches to OS-specific handler
finalize() {
    case "$OS_RELEASE_ID" in
        fedora|centos|rhel|ol|oraclelinux)
            rh_finalize
            ;;
        debian|ubuntu)
            debian_finalize
            ;;
        *)
            die "Unknown/Unsupported Distro '$OS_RELEASE_ID'"
            ;;
    esac
    common_finalize
}

#!/bin/bash

# Disables periodic systemd services that could interfere with CI automation
# Intended to be run during VM image creation

set +e  # Not all services exist on every platform

# Set sudo if not root
if [[ "$UID" -ne 0 ]]; then
    export SUDO="sudo env DEBIAN_FRONTEND=noninteractive"
fi

# Services that run periodically and can interfere with CI
EVIL_UNITS="cron crond atd apt-daily-upgrade apt-daily fstrim motd-news systemd-tmpfiles-clean update-notifier-download mlocate-updatedb plocate-updatedb"

if [[ "$1" == "--list" ]]; then
    echo "$EVIL_UNITS"
    exit 0
fi

echo "Disabling periodic services that could destabilize automation:"
for unit in $EVIL_UNITS; do
    echo "Banishing $unit (ignoring errors)"
    (
        $SUDO systemctl stop "$unit"
        $SUDO systemctl disable "$unit"
        $SUDO systemctl disable "$unit.timer"
        $SUDO systemctl mask "$unit"
        $SUDO systemctl mask "$unit.timer"
    ) &> /dev/null
done

# Disable Debian periodic apt jobs
EAAD="/etc/apt/apt.conf.d"
PERIODIC_APT_RE='^(APT::Periodic::.+")1"\;'
if [[ -d "$EAAD" ]]; then
    echo "Disabling all periodic packaging activity"
    for filename in $($SUDO ls -1 "$EAAD"); do
        echo "Checking/Patching $filename"
        $SUDO sed -i -r -e "s/$PERIODIC_APT_RE/"'\10"\;/' "$EAAD/$filename"
    done
fi

# Disable systemd-resolved if present (can cause DNS flakes in CI)
if ! ((CONTAINER)); then
    nsswitch=/etc/authselect/nsswitch.conf
    if [[ -e $nsswitch ]]; then
        if grep -q -E 'hosts:.*resolve' "$nsswitch"; then
            echo "Disabling systemd-resolved"
            $SUDO sed -i -e 's/^\(hosts: *\).*/\1files dns myhostname/' "$nsswitch"
            $SUDO systemctl disable --now systemd-resolved
            $SUDO rm -f /etc/resolv.conf

            # Restart NetworkManager to regenerate resolv.conf
            $SUDO systemctl start NetworkManager
            sleep 1
            $SUDO systemctl restart NetworkManager

            # Wait for resolv.conf to be created
            retries=10
            while ! test -e /etc/resolv.conf; do
                retries=$((retries - 1))
                if [[ $retries -eq 0 ]]; then
                    echo "WARNING: Timed out waiting for resolv.conf"
                    break
                fi
                $SUDO systemctl restart NetworkManager
                sleep 5
            done
        fi
    fi
fi

echo "Done banishing evil services"

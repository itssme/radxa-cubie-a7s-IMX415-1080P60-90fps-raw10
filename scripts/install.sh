#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KVER="$(uname -r)"

SRC="$ROOT/dist/$KVER/imx415_mipi.ko.xz"
DST="/lib/modules/$KVER/kernel/bsp/drivers/vin/modules/sensor/imx415_mipi.ko.xz"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="${DST}.backup-${STAMP}"

echo
echo "WARNING: EXPERIMENTAL KERNEL DRIVER"
echo
echo "This can break the camera subsystem."
echo "Use only if you understand how to recover the system."
echo "Use entirely at your own risk."
echo

test -f "$SRC" || {
    echo "ERROR: Build the driver first with:"
    echo "  ./scripts/build.sh"
    exit 1
}

test -f "$DST" || {
    echo "ERROR: Existing IMX415 module not found:"
    echo "  $DST"
    exit 1
}

read -r -p 'Type "I ACCEPT THE RISK" to continue: ' ANSWER

if [ "$ANSWER" != "I ACCEPT THE RISK" ]; then
    echo "Aborted."
    exit 1
fi

echo
echo "Backing up current driver:"
echo "  $BACKUP"

sudo cp -a "$DST" "$BACKUP"

echo
echo "Installing new driver..."

sudo cp "$SRC" "$DST"
sudo chmod 0644 "$DST"
sudo /sbin/depmod -a "$KVER"

echo
echo "Installed on disk."
echo
echo "Do NOT hot-reload the VIN camera modules."
echo
echo "Reboot now with:"
echo "  sudo reboot"
echo
echo "Backup:"
echo "  $BACKUP"

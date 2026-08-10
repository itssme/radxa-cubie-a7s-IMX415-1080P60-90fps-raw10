#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/work/allwinner-bsp"
OUT="$ROOT/dist/$(uname -r)"

BSP_URL="https://github.com/radxa/allwinner-bsp.git"
BSP_COMMIT="2045a3ca2a01f088c0314dc924bda59d154e363e"
DRIVER="$WORK/drivers/vin/modules/sensor/imx415_mipi.c"
KVER="$(uname -r)"

if [ ! -d "/lib/modules/$KVER/build" ]; then
    echo "ERROR: Kernel headers not found:"
    echo "  /lib/modules/$KVER/build"
    exit 1
fi

if [ ! -d "$WORK/.git" ]; then
    mkdir -p "$ROOT/work"

    git clone \
        --filter=blob:none \
        --no-checkout \
        "$BSP_URL" \
        "$WORK"

    git -C "$WORK" sparse-checkout init --cone
    git -C "$WORK" sparse-checkout set drivers/vin
fi

git -C "$WORK" fetch origin "$BSP_COMMIT"
git -C "$WORK" checkout --detach "$BSP_COMMIT"
git -C "$WORK" reset --hard "$BSP_COMMIT"

cp "$ROOT/src/imx415_mipi.c" "$DRIVER"

echo "===== BUILD IMX415 ====="

make -C "/lib/modules/$KVER/build" \
    M="$WORK/drivers/vin/modules/sensor" \
    imx415_mipi.ko

mkdir -p "$OUT"

cp \
    "$WORK/drivers/vin/modules/sensor/imx415_mipi.ko" \
    "$OUT/imx415_mipi.ko"

xz -c -9 \
    "$OUT/imx415_mipi.ko" \
    > "$OUT/imx415_mipi.ko.xz"

xz -t "$OUT/imx415_mipi.ko.xz"

echo
echo "===== RESULT ====="
ls -lh \
    "$OUT/imx415_mipi.ko" \
    "$OUT/imx415_mipi.ko.xz"

echo
echo "===== SHA256 ====="
sha256sum \
    "$OUT/imx415_mipi.ko" \
    "$OUT/imx415_mipi.ko.xz"

echo
echo "===== MODULE INFO ====="
/sbin/modinfo "$OUT/imx415_mipi.ko" \
    | grep -E '^(name|depends|vermagic|srcversion):' \
    || true

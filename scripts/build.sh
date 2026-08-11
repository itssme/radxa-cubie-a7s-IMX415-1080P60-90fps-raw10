#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/work/allwinner-bsp"
OUT="$ROOT/dist/$(uname -r)"

BSP_URL="https://github.com/radxa/allwinner-bsp.git"
BSP_COMMIT="2045a3ca2a01f088c0314dc924bda59d154e363e"
DRIVER="$WORK/drivers/vin/modules/sensor/imx415_mipi.c"
KVER="$(uname -r)"

SENSOR_DIR="$WORK/drivers/vin/modules/sensor"

# Build-time exposure in microseconds.
#
# Examples:
#   ./scripts/build.sh                   # default: ~1 ms
#   EXPOSURE_US=1000 ./scripts/build.sh  # ~1 ms
#   EXPOSURE_US=2000 ./scripts/build.sh  # ~2 ms
#   EXPOSURE_US=4000 ./scripts/build.sh  # ~4 ms
#   EXPOSURE_US=0 ./scripts/build.sh     # unrestricted / AWISP controlled
#
# 1080p90 sensor timing:
#   HMAX = 366 clocks
#   clock ~= 74.25 MHz
#
# The driver exposure value is expressed in 1/16-line units.
EXPOSURE_US="${EXPOSURE_US:-1000}"

if ! [[ "$EXPOSURE_US" =~ ^[0-9]+$ ]]; then
    echo "ERROR: EXPOSURE_US must be a non-negative integer."
    exit 1
fi

if [ "$EXPOSURE_US" -eq 0 ]; then
    EXPOSURE_LINES=0
    EXPOSURE_16LINE=0
else
    # Floor to a whole sensor line.
    EXPOSURE_LINES=$(( EXPOSURE_US * 7425 / 36600 ))

    if [ "$EXPOSURE_LINES" -lt 1 ]; then
        EXPOSURE_LINES=1
    fi

    # VMAX=2254; preserve the driver's four-line safety margin.
    if [ "$EXPOSURE_LINES" -gt 2250 ]; then
        echo "ERROR: requested exposure is too long for 1080p90."
        exit 1
    fi

    EXPOSURE_16LINE=$(( EXPOSURE_LINES * 16 ))
fi


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

if [ "$EXPOSURE_US" -eq 0 ]; then
    echo "Exposure: unrestricted / AWISP controlled"
else
    EFFECTIVE_US=$(( EXPOSURE_LINES * 36600 / 7425 ))

    echo "Requested exposure: ${EXPOSURE_US} us"
    echo "Sensor lines:       ${EXPOSURE_LINES}"
    echo "Driver value:       ${EXPOSURE_16LINE} (1/16-line units)"
    echo "Effective exposure: ~${EFFECTIVE_US} us"
fi

# Changing EXPOSURE_US must force the sensor object to be rebuilt.
rm -f \
    "$SENSOR_DIR/imx415_mipi.o" \
    "$SENSOR_DIR/imx415_mipi.ko" \
    "$SENSOR_DIR/.imx415_mipi.o.cmd" \
    "$SENSOR_DIR/.imx415_mipi.ko.cmd"

make -C "/lib/modules/$KVER/build" \
    M="$SENSOR_DIR" \
    KCFLAGS="${KCFLAGS:-} -DIMX415_FORCE_EXP_16LINE_DEFAULT=$EXPOSURE_16LINE" \
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

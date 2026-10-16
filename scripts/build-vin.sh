#!/usr/bin/env bash
# Build the shared VIN fix from an existing BSP checkout; never install it.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSP="${1:?Usage: build-vin.sh /path/to/allwinner-bsp}"
BSP="$(cd "$BSP" && pwd)"
KVER="$(uname -r)"
PATCH="$ROOT/patches/0001-vin-fix-nv12m-chroma-stride.patch"
OUT="$ROOT/dist/$KVER"
if git -C "$BSP" apply --reverse --check "$PATCH" 2>/dev/null; then
    echo 'VIN stride fix already applied.'
else
    git -C "$BSP" apply --check "$PATCH"
    git -C "$BSP" apply "$PATCH"
fi
make -C "/lib/modules/$KVER/build" M="$BSP/drivers/vin" -j2 modules
mkdir -p "$OUT"
cp "$BSP/drivers/vin/vin_v4l2.ko" "$OUT/vin_v4l2.ko"
xz -c -9 "$OUT/vin_v4l2.ko" > "$OUT/vin_v4l2.ko.xz"
xz -t "$OUT/vin_v4l2.ko.xz"
sha256sum "$OUT/vin_v4l2.ko" "$OUT/vin_v4l2.ko.xz"
/sbin/modinfo -F vermagic "$OUT/vin_v4l2.ko"
echo 'Built only; the running and installed modules have not been changed.'

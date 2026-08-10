#!/usr/bin/env bash
set -euo pipefail

echo "===== MODULES ====="
lsmod | grep -E 'imx415_mipi|vin_v4l2|vin_io' || true

echo
echo "===== SENSOR FORMAT ====="
v4l2-ctl \
    -d /dev/v4l-subdev0 \
    --list-subdev-mbus-codes pad=0

echo
echo "===== 1080P60 ====="
v4l2-ctl \
    -d /dev/v4l-subdev0 \
    --list-subdev-frameintervals \
    pad=0,code=0x300e,width=1920,height=1080

echo
echo "Expected:"
echo "  RAW10:       0x300e"
echo "  Resolution:  1920x1080"
echo "  Frame rate:  60 fps"
echo
echo "During an active stream, expected MIPI status:"
echo "  mipi_bps:       891 Mbps"
echo "  int_pending:    0x4f (ok)"
echo "  cur_data_type:  0x2b (RAW10)"

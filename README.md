# Radxa Cubie A7S IMX415 1080p90 RAW10

Experimental IMX415 Linux camera driver configuration for the
Radxa Cubie A7S / Allwinner A733.

## Working configuration

Tested successfully with:

- Board: Radxa Cubie A7S
- SoC: Allwinner A733
- Camera: Radxa 4K Camera / Sony IMX415
- Resolution: 1920x1080
- Frame rate: 90 fps
- Full sensor field of view
- IMX415 2x2 binning
- RAW10
- CSI-2 data type: 0x2b
- CSI-2 lanes: 4
- CSI-2 rate: 1485 Mbps per lane
- Sensor clock: 27 MHz
- Receiver time_hs: 0x20
- Receiver deskew: 0x02
- Stock vin_v4l2 driver

Expected healthy MIPI receiver state:

    mipi_bps:       1485 Mbps
    lane_num:       4 lane
    int_pending:    0x4f (ok)
    cur_data_type:  0x2b (RAW10)

Tested kernel:

    5.15.147-21-a733

Tested Radxa/Allwinner BSP commit:

    2045a3ca2a01f088c0314dc924bda59d154e363e

## WARNING

THIS SOFTWARE IS EXPERIMENTAL.

It is intended for researchers, Linux kernel developers, hardware
developers, and experienced users who understand Linux kernel modules,
V4L2 camera pipelines, CSI-2 interfaces, and system recovery.

Installing an incompatible kernel module can prevent the camera subsystem
from functioning and may require restoring the original module or
operating-system image.

Use this software entirely at your own risk.

There is no guarantee that it will work on another board, camera module,
kernel version, operating-system image, or hardware revision.

Do not use this software in safety-critical, medical, automotive,
industrial-control, or other environments where camera or system failure
could cause injury, damage, or financial loss.

NO WARRANTY IS PROVIDED.

## Repository contents

    src/imx415_mipi.c
    scripts/build.sh
    scripts/install.sh
    scripts/verify.sh

The repository contains source code only. No prebuilt kernel modules,
firmware, ISP binaries, or Sony documentation are included.

## Build

Run:

    ./scripts/build.sh

The script downloads the tested Radxa/Allwinner BSP revision, copies the
known-good IMX415 source into it, and builds imx415_mipi.ko against the
headers for the currently running kernel.

The resulting files are placed under:

    dist/<kernel-version>/

## Install

Review the install script first.

Then run:

    ./scripts/install.sh

The script creates a timestamped backup of the currently installed
IMX415 module before replacing it.

Do not hot-unload and reload the complete Allwinner VIN camera stack.

After installation, reboot:

    sudo reboot

## Verify

After reboot:

    ./scripts/verify.sh

During an active camera stream, the MIPI status can also be inspected with:

    sudo cat /sys/kernel/debug/mpp/mipi

## Example capture

Five seconds of unencoded NV12:

    gst-launch-1.0 -e \
      v4l2src device=/dev/video0 en-awisp=1 en-largemode=0 num-buffers=450 \
      ! video/x-raw,format=NV12,width=1920,height=1080,framerate=90/1 \
      ! filesink location=imx415-1080p90-nv12.raw sync=false

Playback on another machine:

    ffplay \
      -f rawvideo \
      -pixel_format nv12 \
      -video_size 1920x1080 \
      -framerate 90 \
      imx415-1080p90-nv12.raw

## License

The IMX415 driver originates from the Radxa/Allwinner BSP and carries:

    SPDX-License-Identifier: GPL-2.0-or-later

Original copyright and license notices are retained.

This repository is distributed under GPL-2.0-or-later.

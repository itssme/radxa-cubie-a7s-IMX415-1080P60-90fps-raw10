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
- Build-time configurable exposure
- Default exposure on this branch: approximately 1 ms

Expected healthy MIPI receiver state:

```
mipi_bps:       1485 Mbps
lane_num:       4 lane
int_pending:    0x4f (ok)
cur_data_type:  0x2b (RAW10)
```

Tested kernel:

```
5.15.147-21-a733
```

Tested Radxa/Allwinner BSP commit:

```
2045a3ca2a01f088c0314dc924bda59d154e363e
```

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

```
src/imx415_mipi.c
scripts/build.sh
scripts/install.sh
scripts/verify.sh
```

The repository contains source code only. No prebuilt kernel modules,
firmware, ISP binaries, or Sony documentation are included.

## Build

The 1080p90 branch supports a configurable build-time default exposure.

The default is approximately 1 ms:

```
./scripts/build.sh
```

This is equivalent to:

```
EXPOSURE_US=1000 ./scripts/build.sh
```

Other examples:

```
EXPOSURE_US=2000 ./scripts/build.sh
EXPOSURE_US=4000 ./scripts/build.sh
EXPOSURE_US=6000 ./scripts/build.sh
EXPOSURE_US=0 ./scripts/build.sh
```

`EXPOSURE_US=0` disables the forced exposure and leaves exposure
unrestricted so AWISP can control it normally.

The requested exposure is converted to whole IMX415 sensor lines.

For the 1080p90 timing used by this driver:

- HMAX = 366 clocks
- timing clock is approximately 74.25 MHz
- one sensor line is approximately 4.93 us
- the driver exposure control uses 1/16-line units

For example, a requested exposure of 1000 us becomes:

```
202 sensor lines
202 * 16 = 3232 driver exposure units
effective exposure ~= 995 us
```

The build script passes the calculated value to the driver using:

```
IMX415_FORCE_EXP_16LINE_DEFAULT
```

Changing `EXPOSURE_US` forces the IMX415 object to be rebuilt so an object
compiled with an older exposure value is not reused.

The script downloads the tested Radxa/Allwinner BSP revision, copies the
IMX415 source into it, and builds `imx415_mipi.ko` against the headers for
the currently running kernel.

The resulting files are placed under:

```
dist/<kernel-version>/
```

## Runtime exposure override

The build-time exposure value becomes the default whenever the module is
loaded.

It can also be changed at runtime without rebuilding the driver using:

```
/sys/module/imx415_mipi/parameters/force_exp_16line
```

The runtime parameter uses 1/16-line units.

Approximate values for this 1080p90 mode:

```
3232   ~= 1 ms
6464   ~= 2 ms
12928  ~= 4 ms
19392  ~= 6 ms
0      = unrestricted / AWISP controlled
```

For example, force approximately 1 ms:

```
echo 3232 | sudo tee /sys/module/imx415_mipi/parameters/force_exp_16line
```

Force approximately 2 ms:

```
echo 6464 | sudo tee /sys/module/imx415_mipi/parameters/force_exp_16line
```

Return to unrestricted AWISP-controlled exposure:

```
echo 0 | sudo tee /sys/module/imx415_mipi/parameters/force_exp_16line
```

A sysfs change is only a runtime override. It does not change the compiled
default and does not persist across a module reload or reboot.

For example, if the driver was built with:

```
EXPOSURE_US=1000 ./scripts/build.sh
```

then after reboot the parameter should contain:

```
3232
```

## Install

Review the install script first.

Then run:

```
./scripts/install.sh
```

The script creates a timestamped backup of the currently installed
IMX415 module before replacing it.

Do not hot-unload and reload the complete Allwinner VIN camera stack.

After installation, reboot:

```
sudo reboot
```

## Verify

After reboot:

```
./scripts/verify.sh
```

The configured runtime exposure can also be checked with:

```
cat /sys/module/imx415_mipi/parameters/force_exp_16line
```

For the default approximately 1 ms build, the expected value is:

```
3232
```

During an active camera stream, the MIPI status can also be inspected with:

```
sudo cat /sys/kernel/debug/mpp/mipi
```

A healthy 1080p90 RAW10 stream should show approximately:

```
deskew:          0x2
settle_time:     0x20
mipi_bps:        1485 Mbps
lane_num:        4 lane
int_pending:     0x4f (ok)
cur_data_type:   0x2b (RAW10)
```

## Example capture

Five seconds of unencoded NV12 at 1920x1080 90 fps:

```
gst-launch-1.0 -e \
  v4l2src device=/dev/video0 en-awisp=1 en-largemode=0 num-buffers=450 \
  ! video/x-raw,format=NV12,width=1920,height=1080,framerate=90/1 \
  ! filesink location=imx415-1080p90-nv12.raw sync=false
```

The expected file size for 450 NV12 frames is:

```
1920 * 1080 * 3 / 2 * 450
= 1399680000 bytes
```

Playback on another machine:

```
ffplay \
  -f rawvideo \
  -pixel_format nv12 \
  -video_size 1920x1080 \
  -framerate 90 \
  imx415-1080p90-nv12.raw
```

Convert to H.264:

```
ffmpeg \
  -f rawvideo \
  -pixel_format nv12 \
  -video_size 1920x1080 \
  -framerate 90 \
  -i imx415-1080p90-nv12.raw \
  -c:v libx264 \
  -preset fast \
  -crf 18 \
  -pix_fmt yuv420p \
  imx415-1080p90.mp4
```

## Notes about AWISP

The stock Allwinner ISP does not currently have a dedicated tuning
configuration for this experimental 1920x1080 90 fps mode.

It may fall back to the existing IMX415 1080p ISP configuration.

Warnings related to ISP context files, TDM event subscription, AEWB
statistics, sensor flip, sensor temperature, or ISP debug interfaces have
been observed while clean 1080p90 output was still captured successfully.

When forced short exposure is enabled, AWISP can still adjust sensor gain.

For example, testing showed that reducing exposure to approximately 1 ms
caused AWISP to increase gain substantially compared with longer exposure
times. This is expected and can result in a darker or noisier image,
depending on available light.

## License

The IMX415 driver originates from the Radxa/Allwinner BSP and carries:

```
SPDX-License-Identifier: GPL-2.0-or-later
```

Original copyright and license notices are retained.

This repository is distributed under GPL-2.0-or-later.

## NV12 preview color corruption: shared VIN stride fix

On 2026-10-16, a 1080p90 AWISP capture exposed incorrect NV12M metadata in
`vin_video.c`: Y/UV strides were reported as 1920/960 bytes, although the UV
plane actually contains 540 rows of 1920 bytes. JPEG consumers trusting that
stride produced displaced translucent colors and horizontal stripes. The Y
plane was unaffected. Correctly interpreting the same raw buffer removed the
artifacts; direct V4L2 capture delivered 900 frames with zero sequence gaps
and 90.0033 fps after warmup at approximately 3 ms exposure.

`patches/0001-vin-fix-nv12m-chroma-stride.patch` fixes NV12M and NV21M stride
reporting in format negotiation and queue setup. Plane sizes and sensor mode
registers are unchanged. This is a shared VIN fix, not a sensor-driver change.
It applies to the BSP revision pinned in `scripts/build.sh` as well as the
IMX477-derived BSP checkout used on the development board.

Build it against the running kernel headers using an existing BSP checkout:

```sh
./scripts/build-vin.sh /path/to/allwinner-bsp
```

The script applies the patch (or detects it already applied), builds VIN, and
writes `dist/$(uname -r)/vin_v4l2.ko{,.xz}`. It never resets the checkout or
installs a module. The sensor build/install scripts remain sensor-only;
installing `imx415_mipi` alone does not install this shared VIN correction.

Validation: rebuilt successfully against `5.15.147-21-a733`; focused stride
checks cover both corrected formats and unchanged other-format calculations.
The source commit is `74086f23` on `eudis-nv12-stride` in the development
board's `/home/radxa/imx477-build` checkout. The patched kernel module has
not yet been installed or capture-tested. The clean image and timing evidence
above used an explicit userspace stride correction with the original module.

For deployment, back up the existing `vin_v4l2` module, install the rebuilt
module at its existing module path, run `depmod -a`, and reload it while the
camera is idle (or reboot). Then confirm both negotiated strides are 1920,
plane sizes remain 2073600/1036800, and a normal GStreamer JPEG capture is
clean without a userspace override. Preserve a rollback copy of the original
module. No reduction to 60 fps is needed to address this layout error.

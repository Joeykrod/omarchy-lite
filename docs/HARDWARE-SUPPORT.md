# Hardware support

## Primary target

```text
Dell Inspiron 530s (2008)
CPU:    old 2-core x86-64
RAM:    less than 2 GB
GPU:    Intel 82945G / G31 Express integrated graphics
Boot:   legacy BIOS
```

## Why this GPU needs help

These Intel integrated GPUs predate modern OpenGL ES support. Typical
capabilities are:

- OpenGL 2.1,
- OpenGL ES 2.0.

Hyprland requires OpenGL ES 3.0. Without help the compositor may fail to
initialise and drop to a black screen or TTY.

Omarchy Lite handles this by advertising GLES 3.0 to Mesa and forcing llvmpipe
software rendering **only when one of these GPUs is detected**.

## Detection order

1. `lspci -nn`
2. sysfs PCI class scan (`/sys/bus/pci/devices/*/class`)

No external commands beyond standard system tools are used. No network.

## Known legacy PCI IDs

The detection script matches these Intel device IDs:

```text
8086:2562  845G
8086:2572  865G
8086:2582  915G
8086:2592  915GM
8086:2772  82945G / GMA 950
8086:2792  945GM
8086:27a2  945GM Express
8086:27ae  945GME
8086:29a2  G31 / GMA 3100
8086:2a02  GM965 / GMA X3100
8086:2a12  GME965 / GMA X3100
8086:2e02  G45 / GMA X4500
8086:2e12  G45 / GMA X4500HD
8086:2e22  GM45 / GMA X4500MHD
8086:3577  855GM
8086:3582  855GME
8086:8102  852GM
8086:8112  855GM
8086:a011  GMA 3150
8086:a012  GMA 3150
```

It also matches human-readable names such as:

```text
82945G
GMA 950
GMA 3100
GMA X3100
GMA X4500
915GM
945GM
GM45
G31
```

## Modern hardware

On newer Intel, AMD, or NVIDIA GPUs the script intentionally does nothing. It
also removes any stale overrides left by an earlier legacy-GPU run, so the same
installed system or USB can be moved to a newer PC without being stuck in slow
software rendering.

## Manual check

From a terminal:

```bash
lspci -nn | grep -iE 'vga compatible|3d controller|display controller'
```

Then run the detector explicitly:

```bash
omarchy-lite-gpu-detect --force
```

To force the legacy profile regardless of detection:

```bash
omarchy-lite-safe-mode
```

## Logs

```text
/var/log/omarchy-lite-gpu.log
~/.local/state/omarchy-lite/gpu-setup.log
```

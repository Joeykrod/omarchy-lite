# Omarchy Lite

A remastered, **offline-first** Omarchy 4.5.0 ISO for old x86-64 PCs with
small amounts of RAM and legacy integrated graphics.

This is not an official Omarchy edition. It is a local remaster of the official
`omarchy-4.5.0-x86.iso` that keeps the normal Omarchy desktop, theme, top bar,
and `SUPER + SPACE` launcher, while adding low-RAM defaults, a guided repair
agent, a bundled AI coding agent, and automatic legacy-GPU workarounds.

---

## Guided overview

### 1. Who this is for

- Old 2-core x86-64 machines, for example a 2008 Dell Inspiron 530s.
- Less than 2 GB RAM.
- Legacy Intel integrated graphics such as GMA 950 / 915 / 945 / G31 / X3100 /
  X4500.
- Machines with **no reliable internet connection** during setup.
- People who want normal Omarchy, not a completely different desktop.

### 2. What stays the same

- Omarchy launcher: `SUPER + SPACE` — unchanged.
- Omarchy theme, bar, notifications, and menus — unchanged.
- Normal Omarchy installer — unchanged.
- Stock boot entry — still available if the tuned one misbehaves.

### 3. What is added

| Feature | What it does |
|---|---|
| Low-RAM boot entry | Disables costly boot noise, uses `copytoram=n`, adds `mitigations=off` |
| Low-RAM desktop defaults | Animations off, blur/shadow off, `GDK_SCALE=1` |
| Correct colors on old GPUs | Hyprland color management disabled to avoid dark/washed-out fallback shaders |
| Bundled OpenCode | Baseline x64 build, no AVX2 required, no install needed |
| Guided agent | `omarchy-lite-agent` on `SUPER + ALT + A` |
| Automatic legacy GPU detection | Applies software-rendering workarounds only on old Intel GPUs |
| Safe Graphics Mode | Boot entry, TTY command, and agent menu option for black-screen recovery |
| Offline operation | No package downloads, no internet-dependent setup |

### 4. How the automatic GPU fix works

At boot, before the display manager starts, a systemd unit runs:

```text
/usr/local/bin/omarchy-lite-gpu-detect --system --quiet
```

It checks `lspci` and falls back to sysfs. If it finds a known legacy Intel GPU,
it writes:

- `~/.config/uwsm/env.d/60-intel-gles-override`
- `~/.config/uwsm/env.d/61-software-render`
- `~/.config/environment.d/omarchy-lite-gpu.conf`
- `/etc/environment.d/omarchy-lite-gpu.conf`
- `/etc/limine-entry-tool.d/omarchy-lite.conf` containing `mitigations=off`

It then rebuilds the Limine entries with `limine-mkinitcpio` and
`limine-update`.

On a modern GPU, it does the opposite: it removes those files and leaves the
machine on full hardware acceleration. A newer PC is therefore not forced into
slow software rendering.

### 5. Recovery

If Hyprland gives a black screen:

1. Reboot the USB and choose **Omarchy Lite - Safe Graphics Mode** from the boot
   menu.
2. On an installed system, press `Ctrl+Alt+F3`, log in, and run:
   ```bash
   omarchy-lite-safe-mode
   ```
3. Or open the guided agent with `SUPER + ALT + A` and choose:
   ```text
   Repair legacy GPU (offline Safe Graphics Mode)
   ```

`omarchy-lite-safe-mode` forces llvmpipe, re-runs the GPU fix, and restarts the
display manager. It does not need internet.

---

## Repository contents

```text
.
├── README.md                       # this guided description
├── OMARCHY-LITE-README.txt         # plain-text copy placed on the ISO root
├── LICENSE                         # MIT for repo-authored files
├── checksums/
│   └── omarchy-lite.iso.sha256     # SHA-256 of the published build
├── bootinject/
│   └── boot/
│       ├── grub/grub.cfg
│       └── syslinux/archiso_head.cfg
│       └── syslinux/archiso_sys-linux.cfg
├── inject/
│   ├── etc/
│   │   ├── environment.d/
│   │   ├── skel/
│   │   │   ├── .config/hypr/
│   │   │   └── .config/omarchy/
│   │   └── systemd/system/
│   └── usr/
│       ├── local/bin/
│       └── share/omarchy-lite/
├── scripts/
│   ├── prepare-workdir.sh          # verify + extract official ISO
│   ├── build-iso.sh                # inject, repack, checksum, build, verify
│   ├── verify-iso.sh               # verify a built ISO
│   └── flash-usb.sh                # guarded USB writer
└── docs/
    ├── HOW-WE-MADE-IT.md           # detailed build notes / chronology
    ├── HARDWARE-SUPPORT.md         # detected GPUs and PCI IDs
    └── TROUBLESHOOTING.md          # common failure paths
```

The 6.3 GB ISO itself is **not committed** to git. Build it locally with the
scripts below.

---

## Build it yourself

### Prerequisites

On an Arch/Omarchy machine:

```bash
sudo pacman -S --needed xorriso squashfs-tools zstd jq rsync bubblewrap
```

You also need the official ISO:

```text
omarchy-4.5.0-x86.iso
SHA-256: 5d6288bc57f96f6231719830457582c846a2291985201c36a9a7d1216978b00f
```

### 1. Prepare the work directory

```bash
export SRC_ISO=/path/to/omarchy-4.5.0-x86.iso
./scripts/prepare-workdir.sh
```

This verifies the source ISO, extracts it to `../omarchy-remaster/isosource`,
unpacks the live squashfs, decompresses the installed root image, and copies the
repo's injection files into the work directory.

### 2. Build and verify

```bash
./scripts/build-iso.sh
```

The script:

1. injects the offline fixes into the live tree and installed root image,
2. rebuilds `airootfs.sfs`,
3. recompresses `omarchy-root.img.zst`,
4. regenerates checksums in the exact format the installer expects,
5. builds a BIOS+UEFI isohybrid ISO,
6. mounts the ISO and re-verifies both checksum files.

Expected output:

```text
ISO_VERIFIED_OK: .../omarchy-lite.iso
```

### 3. Optional standalone verification

```bash
./scripts/verify-iso.sh ../omarchy-remaster/omarchy-lite.iso
```

### 4. Flash to USB

Put the USB device in place, check `lsblk`, then run:

```bash
USB_DEV=/dev/sdX CONFIRM_USB=YES ./scripts/flash-usb.sh ../omarchy-remaster/omarchy-lite.iso
```

The script refuses to write unless the device reports as a SanDisk Cruzer by
default. Override `EXPECTED_VENDOR` / `EXPECTED_MODEL` for another stick.

---

## Install

1. Boot the target machine and press `F12` on Dell to choose the USB.
2. Select **Omarchy Lite - low RAM / old CPU**.
3. Run the normal Omarchy installer.
4. Point the installer at the internal disk, **not** the USB stick.
5. Reboot.

On the old GPU, the first boot should automatically write the software
rendering overrides before SDDM starts.

---

## Published build checksum

```text
358384ee38a4cb52039551fd57eadd02e0a0a281eb32457dd264078a15d4f402  omarchy-lite.iso
```

This hash is for the build described in `docs/HOW-WE-MADE-IT.md`. Any rebuild
from source will produce a different hash because squashfs/zstd timestamps and
metadata are not byte-reproducible here.

---

## Limitations / non-goals

- No official Omarchy Lite upstream exists; this is a local remaster.
- XFCE + LightDM is **not bundled**. It is not in the offline package mirror and
  would add roughly 1 GB plus version-matched packages. Safe Graphics Mode is
  the offline fallback instead.
- `opencode` can run offline, but `/auth` or provider API calls need internet.
- The tuned boot entry uses `mitigations=off`; use the stock entry if you prefer
  normal CPU security mitigations.
- Deep changes to `/usr/share/omarchy/` are intentionally avoided in this
  source tree; user configuration is injected through `/etc/skel` and systemd.

---

## Credits

Built on [Omarchy](https://omarchy.org/), Arch Linux, Hyprland, Mesa, SDDM,
Limine, and [OpenCode](https://opencode.ai/). This repository only contains the
remaster scripts, configuration, and documentation.

# How we made this possible

This is the detailed story of the working Omarchy Lite remaster. It is written
as notes rather than a polished tutorial because the useful part is the set of
problems we hit and the fixes that survived.

---

## Starting point

We began with the official ISO:

```text
omarchy-4.5.0-x86.iso
SHA-256 5d6288bc57f96f6231719830457582c846a2291985201c36a9a7d1216978b00f
```

There is no official "Omarchy Lite". The goal was to keep real Omarchy 4.5.0
and only trim the parts that break on a 2008-era Dell Inspiron 530s:

- old 2-core x86-64 CPU,
- less than 2 GB RAM,
- Intel 82945G / G31 integrated graphics,
- unreliable/no internet.

The hard constraint was to preserve the Omarchy look and launcher. `SUPER + SPACE`
stays exactly as shipped.

---

## Step 1 — backup before touching the working USB

Before changing the USB, we copied the verified working ISO to system storage:

```text
Work/backups/omarchy-lite-WORKING-20261122.iso
SHA-256 a4afd3788a940e35e03762a736632724925177a7874628047185520ce19589f4
```

Only after that backup was recorded did we rebuild and reflash.

---

## Step 2 — first remaster and the installer checksum failure

The first custom ISO booted, but the installer failed during
"Preparing install target" with messages like:

```text
install medium is corrupt: re-flash it
sha256 mismatch on the root image
sha256sum: omarchy-root.img.zst.sha256: no properly formatted checksum lines found
```

The installer service was effectively running:

```bash
cd /run/archiso/bootmnt/arch/$(uname -m)
sha256sum --check --strict omarchy-root.img.zst.sha256
```

The bug was in how we generated the checksum files. We had written a bare hash:

```text
abc123...
```

But `sha256sum -c` needs the standard format:

```text
abc123...  omarchy-root.img.zst
```

with two spaces and the filename exactly as found on the ISO.

### Fix

Generate the checksums from inside the final `arch/x86_64` directory using the
real tools:

```bash
cd isosource/arch/x86_64
sha256sum omarchy-root.img.zst > omarchy-root.img.zst.sha256
sha512sum airootfs.sfs         > airootfs.sha512
```

Then verify them before packing:

```bash
sha256sum --check --strict omarchy-root.img.zst.sha256
sha512sum --check --strict airootfs.sha512
```

This is now built into `scripts/build-iso.sh`.

---

## Step 3 — preserving BIOS/UEFI boot structure

An early attempt used `xorriso -update` on the original ISO. That was convenient
but it dropped the isohybrid MBR and changed the PVD date, which is dangerous
for a legacy BIOS boot.

### Fix

Extract the original ISO completely, modify the extracted tree, then rebuild
the whole ISO with the original boot options:

```bash
xorriso -as mkisofs \
  -V 'OMARCHY_202611' \
  --modification-date='2026110504484900' \
  -isohybrid-mbr --interval:local_fs:0s-15s:zero_mbrpt,zero_gpt:"$SRC" \
  -partition_cyl_align off \
  -partition_offset 16 \
  --mbr-force-bootable \
  -append_partition 2 0xef --interval:local_fs:12726000d-12775151d::"$SRC" \
  -iso_mbr_part_type 0x00 \
  -c '/boot/syslinux/boot.cat' \
  -b '/boot/syslinux/isolinux.bin' \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -isohybrid-gpt-basdat \
  -eltorito-alt-boot \
  -e 'boot/efi-boot.img' \
  -no-emul-boot \
  -o omarchy-lite.iso \
  isosource
```

We preserved:

```text
archisosearchuuid=2026-11-05-04-48-49-00
PVD date 2026110504484900
```

The result was checked with `xorriso -report_el_torito as_mkisofs` and a real
loop mount. The flashed USB showed:

```text
Device     Boot    Start      End  Sectors Size Id Type
/dev/sdb1  *          64 13146607 13146544 6.3G  0 Empty
/dev/sdb2       13146608 13195759    49152  24M ef EFI (FAT-12/16/32)
```

---

## Step 4 — low-RAM changes that do not change Omarchy

The injected user defaults live in `/etc/skel/.config/...`, so they become the
new user's real config without editing packaged Omarchy defaults.

### Boot entry

Added a default BIOS/GRUB entry named:

```text
Omarchy Lite - low RAM / old CPU
```

with:

```text
copytoram=n
initramfs_options=size=90%
initramfs_async=0
xe.enable_panel_replay=0
mitigations=off
intel_idle.states_off=0x3fc
```

The stock Omarchy entry remains as a fallback.

### Desktop profile

In `~/.config/hypr/looknfeel.lua`:

- animations disabled,
- blur disabled,
- shadow disabled,
- rounding set to 0,
- logo and splash rendering disabled.

In `~/.config/hypr/monitors.lua`:

- scale fixed at 1,
- `GDK_SCALE=1`.

That keeps the same theme and bar, but avoids large framebuffers and expensive
compositor effects on <2 GB RAM.

---

## Step 5 — terminal agents

Two agents were added, both available on old CPUs.

### OpenCode

A baseline x64 OpenCode binary was bundled into:

```text
/usr/local/bin/opencode
```

The baseline build was chosen because it does not require AVX2, so it works on
Core 2 Duo-era CPUs. It is also set as the Omarchy default agent through:

```text
/etc/skel/.config/omarchy/defaults/agent
```

Running OpenCode does not require internet. Only `/auth` or provider API calls
need a connection.

### Guided agent

`omarchy-lite-agent` is a `gum` TUI bound to:

```text
SUPER + ALT + A
```

It provides:

- low-RAM graphics profile,
- offline legacy GPU repair,
- display/resolution help,
- network information,
- system information,
- terminal,
- OpenCode launcher.

The Omarchy launcher on `SUPER + SPACE` was deliberately left untouched.

---

## Step 6 — the "no internet" requirement changed the fallback plan

We originally considered an XFCE + LightDM fallback:

```bash
pacman -S xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
systemctl disable sddm
systemctl enable lightdm
```

But the ISO's offline package mirror did not contain those packages. Bundling
them would add roughly 1 GB of version-matched packages and slow every install.

Because the user said the fix must work without connecting to the internet, we
dropped XFCE/LightDM and implemented an offline **Safe Graphics Mode** instead:

- a boot menu entry using `systemd.setenv` for llvmpipe/GLES overrides,
- an `omarchy-lite-safe-mode` command for TTY recovery,
- a guided-agent menu option.

This keeps the fallback fully offline and avoids changing the desktop.

---

## Step 7 — automating the manual old-GPU fixes

The user had previously fixed the black screen manually with commands like:

```bash
sudo limine-mkinitcpio
sudo limine-update
```

and environment files such as:

```text
~/.config/uwsm/env.d/60-intel-gles-override
~/.config/uwsm/env.d/61-software-render
```

with values:

```text
MESA_GLES_VERSION_OVERRIDE=3.0
MESA_GL_VERSION_OVERRIDE=3.00
LIBGL_ALWAYS_SOFTWARE=1
GALLIUM_DRIVER=llvmpipe
```

All of that is now automated by `inject/usr/local/bin/omarchy-lite-gpu-detect`.

### Why those values are needed

The Intel 82945G/G31 generation exposes OpenGL 2.1 / GLES 2.0. Hyprland needs
GLES 3.0. Mesa version overrides let Hyprland initialise, and llvmpipe provides
a software renderer when the old hardware cannot satisfy the compositor.

### Detection

The script checks `lspci -nn` first, then sysfs. It matches known legacy Intel
PCI IDs and names. See `docs/HARDWARE-SUPPORT.md`.

### What happens on a legacy GPU

- writes user and system environment files,
- writes uwsm env overrides,
- disables split-monitor-workspaces plugin config,
- adds `mitigations=off` to `/etc/limine-entry-tool.d/omarchy-lite.conf`,
- runs `limine-mkinitcpio` and `limine-update` if `/boot` or `/efi` is mounted.

### What happens on a modern GPU

- no override files are written,
- any previously written override files are removed,
- the Limine drop-in is removed and updated.

That last part matters because the same USB may be used on a newer PC later.

---

## Step 8 — making it run before the desktop

Two hook points were used.

### Systemd unit

```text
/etc/systemd/system/omarchy-lite-gpu-detect.service
```

Enabled through:

```text
/etc/systemd/system/multi-user.target.wants/
```

It runs with `--system --quiet` before `sddm.service` and
`display-manager.service`.

### User post-boot hook

```text
/etc/skel/.config/omarchy/hooks/post-boot.d/omarchy-lite-gpu.sh
```

This is a safety net for users created after installation. It only touches the
current user's config and is a no-op on modern GPUs.

---

## Step 8a — fixing the color-blind-looking interface

Everything worked, but the desktop colors looked wrong — dark/washed out, as
if a color filter were applied.

This is a known Hyprland failure on older GPUs. The color-management shader
requires GLSL ES 3.20, but these Intel GMA chips only advertise GLES 3.0. The
shader fails to compile and Hyprland falls back to a broken path that renders
colors badly.

### Fix

Add this to the injected user Hyprland config:

```lua
hl.config({
  render = {
    cm_enabled = false,
  },
})
```

This is in `inject/etc/skel/.config/hypr/looknfeel.lua`, so it is part of a
fresh install. It is offline, needs no package, and does not change the theme,
launcher, or keybindings.

### Applying it to an already-installed machine without reinstalling

```bash
cat >> ~/.config/hypr/looknfeel.lua <<'EOF'

-- Omarchy Lite: correct colors on old GLES 3.0 GPUs
hl.config({ render = { cm_enabled = false } })
EOF
hyprctl reload
```

---

## Step 9 — clean-source note

An earlier experiment also placed duplicate Hyprland config files under
`/usr/share/omarchy/config/hypr/`. Those are harmless but not a good long-term
pattern because Omarchy updates overwrite packaged files.

This repository's reproducible source intentionally keeps customization in:

```text
/etc/skel/.config/
/etc/environment.d/
/etc/systemd/system/
/usr/local/bin/
```

Do not edit `/usr/share/omarchy/` for end-user customization.

---

## Step 10 — final verification

Before publishing/flashing we verified:

1. source ISO SHA-256,
2. generated checksum files on the built ISO,
3. checksums re-checked from a loop-mounted ISO,
4. BIOS/UEFI El Torito settings,
5. PVD volume ID and date,
6. live squashfs contains the GPU scripts and safe-mode command,
7. installed root image contains the same scripts and enabled systemd unit,
8. USB verified byte-for-byte against the ISO for the full ISO length after
   flashing, with the installer checksums rechecked from the USB itself,
9. USB partition table after flashing.

Final published ISO SHA-256:

```text
358384ee38a4cb52039551fd57eadd02e0a0a281eb32457dd264078a15d4f402
```

---

## What we deliberately did not do

- Did not touch `/dev/sda`.
- Did not publish the 6.3 GB ISO in git.
- Did not force software rendering on modern PCs.
- Did not change the `SUPER + SPACE` launcher.
- Did not add an internet-dependent fallback.
- Did not hardcode a sudo password anywhere in the repo.

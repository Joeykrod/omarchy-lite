# Troubleshooting

## Installer says "install medium is corrupt"

This was the original checksum-format bug.

The installer runs:

```bash
cd /run/archiso/bootmnt/arch/$(uname -m)
sha256sum --check --strict omarchy-root.img.zst.sha256
```

The checksum file must look like:

```text
<64-hex-hash>  omarchy-root.img.zst
```

not a bare hash. Verify the ISO:

```bash
./scripts/verify-iso.sh omarchy-lite.iso
```

If it fails, rebuild with `scripts/build-iso.sh`. Do not hand-edit the checksum
files.

---

## Black screen after install on the old Dell

Try, in order:

1. Reboot and choose **Omarchy Lite - Safe Graphics Mode** from the USB boot
   menu.
2. From a TTY: `Ctrl+Alt+F3`, log in, then:
   ```bash
   omarchy-lite-safe-mode
   ```
3. If SDDM does not come back:
   ```bash
   sudo systemctl restart sddm
   ```
   or reboot.

Check the log:

```bash
tail -50 /var/log/omarchy-lite-gpu.log
```

---

## New PC is slow / stuck in software rendering

Run:

```bash
sudo omarchy-lite-gpu-detect --system --force
```

On modern hardware the detector removes the legacy overrides and Limine
drop-in. Then reboot.

---

## Colors look dark/washed out, like a color-blind filter

On old GLES 3.0 GPUs, Hyprland's color-management shader needs GLSL ES 3.20 and
falls back to a broken path. Disable color management:

```bash
cat >> ~/.config/hypr/looknfeel.lua <<'EOF'

-- Omarchy Lite: correct colors on old GLES 3.0 GPUs
hl.config({ render = { cm_enabled = false } })
EOF
hyprctl reload
```

This is already baked into fresh installs from the fixed ISO. No reboot or
internet connection is needed.

---

## OpenCode will not start

The binary is bundled at:

```text
/usr/local/bin/opencode
```

Try it directly:

```bash
/usr/local/bin/opencode --version
```

If that works but the menu launcher does not, check `PATH`. The guided agent
falls back to the absolute path automatically.

Signing in with `/auth` needs internet. Running OpenCode does not.

---

## SUPER + SPACE launcher changed

It should not. Omarchy Lite only adds `SUPER + ALT + A`.

If the launcher is missing, the Hyprland user config may be incomplete. Restore
from stock Omarchy with:

```bash
omarchy refresh hyprland
```

Then reapply the Omarchy Lite low-RAM profile from the guided agent if needed.

---

## USB will not boot on legacy BIOS

Check that the ISO was written with `dd`, not merely copied as a file.

Check the USB partition table:

```bash
sudo fdisk -l /dev/sdX
```

Expected layout:

```text
/dev/sdX1  *          64 13146607 13146544 6.3G  0 Empty
/dev/sdX2       13146608 13195759    49152  24M ef EFI (FAT-12/16/32)
```

If the first partition is not bootable or the EFI partition is missing, reflash:

```bash
USB_DEV=/dev/sdX CONFIRM_USB=YES ./scripts/flash-usb.sh omarchy-lite.iso
```

---

## Build fails because the root image is mounted read-only

`build-iso.sh` needs to mount `omarchy-root.img` read-write. It always unmounts
and remounts the loop fresh because a loop device first mounted read-only cannot
be remounted read-write.

If a stale mount exists:

```bash
sudo umount /mnt/omarchy-root 2>/dev/null || true
```

Then rerun the build.

---

## I do not want `mitigations=off`

Use the **Omarchy - stock settings** boot entry, or remove:

```text
/etc/limine-entry-tool.d/omarchy-lite.conf
```

then run:

```bash
sudo limine-update
```

Note that the GPU detector may recreate that drop-in on detected legacy
hardware. On modern hardware it removes it.

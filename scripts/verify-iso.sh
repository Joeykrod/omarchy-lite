#!/usr/bin/env bash
# Verify an Omarchy Lite ISO locally before flashing.
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/omarchy-lite.iso" >&2
  exit 2
fi

ISO=$(readlink -f "$1")
[[ -f "$ISO" ]] || { echo "ISO not found: $ISO" >&2; exit 1; }

if [[ $EUID -ne 0 ]]; then
  exec sudo bash "$0" "$ISO"
fi

for cmd in xorriso mount umount sha256sum sha512sum; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Missing required command: $cmd" >&2; exit 1; }
done

MOUNT=$(mktemp -d /tmp/opencode/isoverify.XXXXXX)
trap 'umount "$MOUNT" 2>/dev/null || true; rmdir "$MOUNT" 2>/dev/null || true' EXIT

echo "== ISO metadata =="
xorriso -indev "$ISO" -pvd_info 2>/dev/null | grep -E 'Volume Id|Creation Time|Modif. Time'
xorriso -indev "$ISO" -report_el_torito as_mkisofs 2>/dev/null | grep -E \
  'isohybrid-mbr|mbr-force-bootable|boot-info-table|append_partition|eltorito-alt-boot'

mount -o loop,ro "$ISO" "$MOUNT"

echo "== Checksum files on ISO =="
cat "$MOUNT/arch/x86_64/omarchy-root.img.zst.sha256"
cat "$MOUNT/arch/x86_64/airootfs.sha512"

echo "== Verify checksums from ISO =="
(
  cd "$MOUNT/arch/x86_64"
  sha256sum --check --strict omarchy-root.img.zst.sha256
  sha512sum --check --strict airootfs.sha512
)

echo "== Boot markers =="
grep -m1 'Omarchy Lite' "$MOUNT/boot/syslinux/archiso_sys-linux.cfg"
grep -m1 'Safe Graphics Mode' "$MOUNT/boot/grub/grub.cfg"
grep -m1 'mitigations=off' "$MOUNT/boot/grub/grub.cfg"

echo "== ISO root files =="
ls -lh "$MOUNT/OMARCHY-LITE-README.txt"

echo "ISO_VERIFY_OK: $ISO"

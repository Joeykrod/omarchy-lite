#!/usr/bin/env bash
# Write an Omarchy Lite ISO to a USB stick, with conservative safety checks.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  exec sudo bash "$0" "$@"
fi

ISO=${1:-${ISO:-}}
USB_DEV=${USB_DEV:-/dev/sdb}
EXPECTED_VENDOR=${EXPECTED_VENDOR:-SanDisk}
EXPECTED_MODEL=${EXPECTED_MODEL:-Cruzer}
EXPECTED_TRAN=${EXPECTED_TRAN:-usb}

if [[ -z "$ISO" ]]; then
  echo "Usage: USB_DEV=/dev/sdX CONFIRM_USB=YES $0 /path/to/omarchy-lite.iso" >&2
  exit 2
fi
if [[ ${CONFIRM_USB:-} != YES ]]; then
  echo "Refusing to write without explicit confirmation." >&2
  echo "Set CONFIRM_USB=YES after checking the device with lsblk." >&2
  exit 2
fi
if [[ "$USB_DEV" == /dev/sda ]]; then
  echo "ABORT: refusing to write to /dev/sda" >&2
  exit 1
fi
[[ -f "$ISO" ]] || { echo "ISO not found: $ISO" >&2; exit 1; }
[[ -b "$USB_DEV" ]] || { echo "Not a block device: $USB_DEV" >&2; exit 1; }

VENDOR=$(lsblk -dno VENDOR "$USB_DEV" 2>/dev/null | tr -d ' ' || true)
MODEL=$(lsblk -dno MODEL "$USB_DEV" 2>/dev/null | xargs || true)
TRAN=$(lsblk -dno TRAN "$USB_DEV" 2>/dev/null | tr -d ' ' || true)
SIZE=$(lsblk -dno SIZE "$USB_DEV" 2>/dev/null | tr -d ' ' || true)

echo "Target: $USB_DEV | vendor=$VENDOR model=$MODEL transport=$TRAN size=$SIZE"

if [[ -z "$SIZE" || "$SIZE" == "0B" ]]; then
  echo "ABORT: target has no size; replug the USB and retry." >&2
  exit 1
fi
if [[ "$VENDOR" != *"$EXPECTED_VENDOR"* || "$MODEL" != *"$EXPECTED_MODEL"* || "$TRAN" != "$EXPECTED_TRAN" ]]; then
  echo "ABORT: $USB_DEV is not the expected $EXPECTED_VENDOR $EXPECTED_MODEL USB." >&2
  exit 1
fi

echo "Unmounting partitions..."
for part in "${USB_DEV}"[0-9]*; do
  [[ -b "$part" ]] || continue
  mp=$(findmnt -rn -o TARGET "$part" 2>/dev/null || true)
  [[ -n "$mp" ]] && umount "$mp" 2>/dev/null || true
  umount "$part" 2>/dev/null || true
done

echo "== Writing $(basename "$ISO") to $USB_DEV =="
wipefs -a "$USB_DEV" >/dev/null 2>&1 || true
dd if="$ISO" of="$USB_DEV" bs=4M status=progress conv=fsync
sync

echo "== Verifying first 1 MiB =="
ISO_HEAD=$(head -c 1048576 "$ISO" | sha256sum | awk '{print $1}')
USB_HEAD=$(dd if="$USB_DEV" bs=1M count=1 status=none | sha256sum | awk '{print $1}')
echo "iso: $ISO_HEAD"
echo "usb: $USB_HEAD"
[[ "$ISO_HEAD" == "$USB_HEAD" ]] || { echo "ABORT: first-MiB mismatch" >&2; exit 1; }

echo "== Partition table =="
fdisk -l "$USB_DEV" | head -20
eject "$USB_DEV" 2>/dev/null || true
echo "DONE: USB is ready. Replug if desired and boot with F12."

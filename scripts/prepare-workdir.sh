#!/usr/bin/env bash
# Verify the official Omarchy ISO and prepare a local remaster work directory.
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)

SRC_ISO=${SRC_ISO:-$HOME/Downloads/omarchy-4.5.0-x86.iso}
WORK_DIR=${WORK_DIR:-$REPO_ROOT/../omarchy-remaster}
EXPECTED_SHA256=5d6288bc57f96f6231719830457582c846a2291985201c36a9a7d1216978b00f

for cmd in sha256sum xorriso unsquashfs zstd; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Missing required command: $cmd" >&2; exit 1; }
done

[[ -f "$SRC_ISO" ]] || { echo "Source ISO not found: $SRC_ISO" >&2; exit 1; }

echo "== Verifying source ISO =="
actual=$(sha256sum "$SRC_ISO" | awk '{print $1}')
if [[ "$actual" != "$EXPECTED_SHA256" ]]; then
  echo "ABORT: source ISO SHA-256 mismatch" >&2
  echo "  expected: $EXPECTED_SHA256" >&2
  echo "  actual:   $actual" >&2
  exit 1
fi
echo "   source ISO OK"

mkdir -p "$WORK_DIR"

echo "== Extracting ISO tree =="
if [[ ! -d "$WORK_DIR/isosource" ]]; then
  xorriso -indev "$SRC_ISO" -osirrox on -extract / "$WORK_DIR/isosource"
else
  echo "   already present: $WORK_DIR/isosource"
fi

LIVE_SFS="$WORK_DIR/isosource/arch/x86_64/airootfs.sfs"
ROOT_ZST="$WORK_DIR/isosource/arch/x86_64/omarchy-root.img.zst"
[[ -f "$LIVE_SFS" ]] || { echo "Missing $LIVE_SFS" >&2; exit 1; }
[[ -f "$ROOT_ZST" ]] || { echo "Missing $ROOT_ZST" >&2; exit 1; }

echo "== Unpacking live squashfs =="
if [[ ! -d "$WORK_DIR/squashfs-root" ]]; then
  unsquashfs -d "$WORK_DIR/squashfs-root" "$LIVE_SFS"
else
  echo "   already present: $WORK_DIR/squashfs-root"
fi

echo "== Decompressing installed root image =="
if [[ ! -f "$WORK_DIR/omarchy-root.img" ]]; then
  zstd -d -f "$ROOT_ZST" -o "$WORK_DIR/omarchy-root.img"
else
  echo "   already present: $WORK_DIR/omarchy-root.img"
fi

echo "== Copying repo injection files =="
cp -a "$REPO_ROOT/inject/." "$WORK_DIR/inject/"
cp -a "$REPO_ROOT/bootinject/." "$WORK_DIR/bootinject/"
cp -f "$REPO_ROOT/OMARCHY-LITE-README.txt" "$WORK_DIR/OMARCHY-LITE-README.txt"

echo "WORKDIR_READY: $WORK_DIR"

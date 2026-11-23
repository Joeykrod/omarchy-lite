#!/usr/bin/env bash
# Build a verified Omarchy Lite ISO from a prepared work directory.
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)

if [[ $EUID -ne 0 ]]; then
  exec sudo bash "$0" "$@"
fi

WORK_DIR=${WORK_DIR:-$REPO_ROOT/../omarchy-remaster}
SRC_ISO=${SRC_ISO:-$HOME/Downloads/omarchy-4.5.0-x86.iso}
OUT_NAME=${OUT_NAME:-omarchy-lite.iso}

cd "$WORK_DIR"

ARCHDIR=isosource/arch/x86_64
LIVE=squashfs-root
ROOTMNT=/mnt/omarchy-root
ROOT=$ROOTMNT/omarchy-root
INJECT=$REPO_ROOT/inject
BOOTINJECT=$REPO_ROOT/bootinject
OUT=$WORK_DIR/$OUT_NAME

for d in isosource "$LIVE" "$INJECT" "$BOOTINJECT"; do
  [[ -e "$d" ]] || { echo "Missing required path: $d" >&2; exit 1; }
done
[[ -f omarchy-root.img ]] || { echo "Missing omarchy-root.img" >&2; exit 1; }

# ---------------------------------------------------------------------------
echo "== 1. Inject offline fixes into live tree and installed root image =="

# Always start from an unmounted loop; read-only loop devices cannot be upgraded.
umount "$ROOTMNT" 2>/dev/null || true
mkdir -p "$ROOTMNT"
mount -o loop,rw "$PWD/omarchy-root.img" "$ROOTMNT"
[[ -d "$ROOT" ]] || { echo "Missing $ROOT inside root image" >&2; exit 1; }

for TREE in "$LIVE" "$ROOT"; do
  cp -a "$INJECT"/. "$TREE"/

  chown -R root:root \
    "$TREE/etc/systemd/system/omarchy-lite-gpu-detect.service" \
    "$TREE/etc/skel/.config/omarchy/hooks/post-boot.d/omarchy-lite-gpu.sh" \
    "$TREE/usr/local/bin/omarchy-lite-gpu-detect" \
    "$TREE/usr/local/bin/omarchy-lite-safe-mode" \
    "$TREE/usr/local/bin/omarchy-lite-agent" \
    "$TREE/usr/local/bin/omarchy-lite-lowram" \
    "$TREE/usr/share/omarchy-lite"

  chmod 0755 \
    "$TREE/usr/local/bin/omarchy-lite-gpu-detect" \
    "$TREE/usr/local/bin/omarchy-lite-safe-mode" \
    "$TREE/usr/local/bin/omarchy-lite-agent" \
    "$TREE/usr/local/bin/omarchy-lite-lowram" \
    "$TREE/etc/skel/.config/omarchy/hooks/post-boot.d/omarchy-lite-gpu.sh"

  mkdir -p "$TREE/etc/systemd/system/multi-user.target.wants"
  ln -sfn /etc/systemd/system/omarchy-lite-gpu-detect.service \
    "$TREE/etc/systemd/system/multi-user.target.wants/omarchy-lite-gpu-detect.service"
done

sync
umount "$ROOTMNT"

# ---------------------------------------------------------------------------
echo "== 2. Rebuild the live squashfs =="
rm -f airootfs-new.sfs
mksquashfs "$LIVE" airootfs-new.sfs \
  -noappend -no-progress -comp zstd -Xcompression-level 10 -b 1048576 \
  >mksquashfs.log 2>&1
echo "   airootfs-new.sfs rebuilt"

# ---------------------------------------------------------------------------
echo "== 3. Recompress the installed root image =="
zstd -T4 -10 -f omarchy-root.img -o omarchy-root-new.img.zst
zstd -t omarchy-root-new.img.zst >/dev/null
echo "   zstd stream integrity OK"

# ---------------------------------------------------------------------------
echo "== 4. Install final-named files into the ISO source tree =="
cp -f airootfs-new.sfs          "$ARCHDIR/airootfs.sfs"
cp -f omarchy-root-new.img.zst  "$ARCHDIR/omarchy-root.img.zst"
cp -f "$BOOTINJECT/boot/syslinux/archiso_head.cfg"      isosource/boot/syslinux/
cp -f "$BOOTINJECT/boot/syslinux/archiso_sys-linux.cfg" isosource/boot/syslinux/
cp -f "$BOOTINJECT/boot/grub/grub.cfg"                  isosource/boot/grub/
cp -f "$REPO_ROOT/OMARCHY-LITE-README.txt"              isosource/

# ---------------------------------------------------------------------------
echo "== 5. Generate installer-compatible checksums =="
(
  cd "$ARCHDIR"
  sha256sum omarchy-root.img.zst > omarchy-root.img.zst.sha256
  sha512sum airootfs.sfs         > airootfs.sha512
)

# ---------------------------------------------------------------------------
echo "== 6. Verify checksums before packing =="
(
  cd "$ARCHDIR"
  sha256sum --check --strict omarchy-root.img.zst.sha256
  sha512sum --check --strict airootfs.sha512
)

# ---------------------------------------------------------------------------
echo "== 7. Build isohybrid ISO =="
rm -f "$OUT"
xorriso -as mkisofs \
  -V 'OMARCHY_202611' \
  --modification-date='2026110504484900' \
  -isohybrid-mbr --interval:local_fs:0s-15s:zero_mbrpt,zero_gpt:"$SRC_ISO" \
  -partition_cyl_align off \
  -partition_offset 16 \
  --mbr-force-bootable \
  -append_partition 2 0xef --interval:local_fs:12726000d-12775151d::"$SRC_ISO" \
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
  -o "$OUT" \
  isosource

# ---------------------------------------------------------------------------
echo "== 8. Verify built ISO =="
bash "$SCRIPT_DIR/verify-iso.sh" "$OUT"

echo "ISO_VERIFIED_OK: $OUT"
ls -lh "$OUT"

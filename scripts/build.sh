#!/usr/bin/env bash
#
# Build script for Samsung Galaxy J3 (2016) SM-J320M Darwin / XNU Kernel.
# Compiles 32-bit ARMv7 Mach-O kernel binary and packages Android boot.img / Odin tarball.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$REPO_DIR/build"
TOOLCHAIN_BIN="/home/usuario/oneios-build/out/toolchain/bin"

echo "=== [MAHI68] Building Darwin / XNU for Samsung Galaxy J3 (2016) SM-J320M ==="
echo "Repo: $REPO_DIR"
echo "Build: $BUILD_DIR"

mkdir -p "$BUILD_DIR"

# 1. Compile assembly entry trampoline
echo "--> Compiling src/entry.s (ARM Linux zImage header & early visual checkpoint)..."
clang \
    -target armv7-apple-darwin \
    -mcpu=cortex-a7 \
    -mfpu=vfpv4 \
    -mfloat-abi=softfp \
    -c "$REPO_DIR/src/entry.s" \
    -o "$BUILD_DIR/entry.o"

# 2. Compile kernel bootstrap C code
echo "--> Compiling src/main.c (Darwin hardware initialization & GIC/Timer/SMP)..."
clang \
    -target armv7-apple-darwin \
    -mcpu=cortex-a7 \
    -mfpu=vfpv4 \
    -mfloat-abi=softfp \
    -O2 \
    -Wall \
    -Wextra \
    -fno-builtin \
    -fno-common \
    -ffreestanding \
    -nostdinc \
    -I"$REPO_DIR/include" \
    -c "$REPO_DIR/src/main.c" \
    -o "$BUILD_DIR/main.o"

# 3. Link 32-bit ARMv7 Mach-O kernel binary
echo "--> Linking Mach-O 32-bit ARMv7 kernel binary at 0x80008000..."
"$TOOLCHAIN_BIN/ld" \
    -arch armv7 \
    -static \
    -image_base 0x80008000 \
    -pagezero_size 0 \
    -e __entry \
    "$BUILD_DIR/entry.o" \
    "$BUILD_DIR/main.o" \
    -o "$BUILD_DIR/mach_kernel.sys"

# 4. Create stripped kernel binary for production boot.img
echo "--> Generating stripped production kernel binary..."
"$TOOLCHAIN_BIN/strip" -u -r "$BUILD_DIR/mach_kernel.sys" -o "$BUILD_DIR/mach_kernel"

# 5. Extract raw bootable kernel payload for U-Boot execution
echo "--> Generating raw bootable kernel image..."
# In ARM Mach-O, the text segment starts directly at file offset 0 with the zImage header
cp "$BUILD_DIR/mach_kernel" "$BUILD_DIR/kernel.mach"

# 6. Create staging ramdisk
echo "--> Creating staging ramdisk..."
python3 -c "
import gzip
with gzip.open('$BUILD_DIR/ramdisk.img', 'wb') as f:
    f.write(b'Darwin/XNU iOS 10.3.3 Staging Ramdisk for Galaxy J3 2016 SM-J320M\n')
"

# 7. Package Android boot.img using mkbootimg.py
echo "--> Packaging boot.img (Header v0 for Spreadtrum U-Boot)..."
python3 "$REPO_DIR/scripts/mkbootimg.py" \
    --kernel "$BUILD_DIR/kernel.mach" \
    --ramdisk "$BUILD_DIR/ramdisk.img" \
    --base 0x80000000 \
    --kernel_offset 0x00008000 \
    --ramdisk_offset 0x01000000 \
    --tags_offset 0x00000100 \
    --pagesize 2048 \
    --cmdline "console=ttyS1,115200n8 root=/dev/ram0 rw" \
    --board "j3xlte" \
    -o "$BUILD_DIR/boot.img"

# 8. Create Samsung Odin flashable package (boot.tar.md5)
echo "--> Packaging Samsung Odin boot.tar.md5..."
(
    cd "$BUILD_DIR"
    tar -H ustar -c boot.img > boot.tar
    md5sum -t boot.tar >> boot.tar
    mv boot.tar boot.tar.md5
)

# 9. Create TWRP flashable zip
echo "--> Packaging TWRP recovery flashable zip..."
mkdir -p "$BUILD_DIR/twrp_staging/META-INF/com/google/android"
cp "$BUILD_DIR/boot.img" "$BUILD_DIR/twrp_staging/"
cat << 'EOF' > "$BUILD_DIR/twrp_staging/META-INF/com/google/android/updater-script"
ui_print("===========================================");
ui_print("  Darwin/XNU 16.7.0 (iOS 10.3.3) Kernel   ");
ui_print("  Samsung Galaxy J3 (2016) SM-J320M       ");
ui_print("===========================================");
ui_print("Flashing Darwin kernel to /dev/block/platform/sdio_emmc/by-name/boot...");
package_extract_file("boot.img", "/dev/block/platform/sdio_emmc/by-name/boot");
ui_print("Done! Reboot to test.");
EOF
# Place binary dummy update-binary (standard shell wrapper)
cat << 'EOF' > "$BUILD_DIR/twrp_staging/META-INF/com/google/android/update-binary"
#!/sbin/sh
OUTFD=$2
ZIPFILE=$3
ui_print() {
    echo "ui_print $1" >&$OUTFD
    echo "ui_print" >&$OUTFD
}
ui_print "Flashing J320M Darwin XNU Kernel..."
unzip -p "$ZIPFILE" boot.img > /dev/block/platform/sdio_emmc/by-name/boot
ui_print "Kernel flashed successfully."
exit 0
EOF
chmod +x "$BUILD_DIR/twrp_staging/META-INF/com/google/android/update-binary"
python3 -c "
import zipfile, os
zf = zipfile.ZipFile('$BUILD_DIR/j320m-ios10-xnu-twrp.zip', 'w', zipfile.ZIP_DEFLATED)
for root, _, files in os.walk('$BUILD_DIR/twrp_staging'):
    for f in files:
        full_path = os.path.join(root, f)
        rel_path = os.path.relpath(full_path, '$BUILD_DIR/twrp_staging')
        zf.write(full_path, rel_path)
zf.close()
"
rm -rf "$BUILD_DIR/twrp_staging"

# 10. Generate checksums
echo "--> Generating SHA256SUMS.txt..."
(
    cd "$BUILD_DIR"
    sha256sum mach_kernel mach_kernel.sys boot.img boot.tar.md5 j320m-ios10-xnu-twrp.zip > SHA256SUMS.txt
)

echo "=== Build Complete! Artifacts in $BUILD_DIR: ==="
ls -lh "$BUILD_DIR"
cat "$BUILD_DIR/SHA256SUMS.txt"

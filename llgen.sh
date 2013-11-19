#!/bin/bash

CURDIR="$(cd `dirname $0` && pwd)"

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

if [ -z "$1" ]; then
	echo "Usage: $0 <target directory>"
	exit 1
fi

# check working directory
if [ ! -d "$1" ]; then echo "$1 not found" && exit 1; fi

WDIR="$(cd "$1" && pwd)" || exit 1
CHRDIR="$WDIR/chroot"
IMGDIR="$WDIR/image"

cp "$CHRDIR/boot/vmlinuz-"* "$IMGDIR/casper/vmlinuz"
cp "$CHRDIR/boot/initrd.img-"* "$IMGDIR/casper/initrd.lz"
cp "/usr/lib/syslinux/isolinux.bin" "$IMGDIR/isolinux/isolinux.bin"
cp "/boot/memtest86+.bin" "$IMGDIR/install/memtest"

# Create manifest
chroot "$CHRDIR" dpkg-query -W --showformat='${Package} ${Version}\n' | tee "$IMGDIR/casper/filesystem.manifest"

# Compress the chroot
mksquashfs "$CHRDIR" "$IMGDIR/casper/filesystem.squashfs" -e boot
printf $(du -sx --block-size=1 "$CHRDIR" | cut -f1) > "$IMGDIR/casper/filesystem.size"

# Calculate MD5
(cd "$IMGDIR" && find . -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > "md5sum.txt")

# Create ISO
cd "$IMGDIR"
mkisofs -r -V "UbuntuRemix" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o "$CURDIR/ubuntu-remix.iso" .
cd "$CURDIR"
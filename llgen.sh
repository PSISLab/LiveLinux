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
ISODIR="$WDIR/iso"
IMGDIR="$WDIR/img"

cp "$CHRDIR/boot/vmlinuz-"* "$ISODIR/casper/vmlinuz" || exit 1
cp "$CHRDIR/boot/initrd.img-"* "$ISODIR/casper/initrd.lz" || exit 1
cp "/usr/lib/syslinux/isolinux.bin" "$ISODIR/isolinux/isolinux.bin" || exit 1
cp "/boot/memtest86+.bin" "$ISODIR/install/memtest" || exit 1

# Create manifest
chroot "$CHRDIR" dpkg-query -W --showformat='${Package} ${Version}\n' | tee "$ISODIR/casper/filesystem.manifest" || exit 1

# Compress the chroot
mksquashfs "$CHRDIR" "$ISODIR/casper/filesystem.squashfs" -noappend -e boot || exit 1
printf $(du -sx --block-size=1 "$CHRDIR" | cut -f1) > "$ISODIR/casper/filesystem.size" || exit 1

# Calculate MD5
(cd "$ISODIR" && find . -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > "md5sum.txt") || exit 1

# Create ISO
cd "$ISODIR" || exit 1
#mkisofs -r -V "UbuntuRemix" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o "ubuntu-remix.iso" .
cd "$CURDIR"

# Create bootable image
cd "$IMGDIR" || exit 1
dd if=/dev/zero of=loop bs=1 count=1 seek=700M
mkfs.ext2 -L rescue -m 0 loop

ln -s "$ISODIR" tmp || exit 1
mount -o loop loop mnt

cp -a tmp/* mnt/

cd mnt
mkdir boot
mv isolinux boot/extlinux
mv boot/extlinux/isolinux.cfg boot/extlinux/extlinux.conf
extlinux --install boot/extlinux/
cd ..
umount mnt
rm tmp

gzip -c loop > ubuntu-remix.img.gz
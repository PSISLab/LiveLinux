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

# create working directory
if [ -d "$1" ]; then echo "$1 already exists" && exit 1; fi
mkdir -p "$1" || exit 1
touch 

WDIR="$(cd "$1" && pwd)" || exit 1
CHRDIR="$WDIR/chroot"
ISODIR="$WDIR/iso"
IMGDIR="$WDIR/img"

# Install debootstrap
apt-get install --yes debootstrap || exit 1

# Install tools for creating iso
apt-get install --yes netpbm syslinux squashfs-tools genisoimage extlinux || exit 1

function setup_chroot
{
	# Bootstrap Ubuntu with same arch and release
	mkdir -p "$CHRDIR" || return 1
	RELEASE="$(lsb_release -sc)"
	debootstrap "$RELEASE" "$CHRDIR" || return 1
	
	# Copy apt sources.list configuration
	cp "/etc/apt/sources.list" "$CHRDIR/etc/apt/sources.list" || return 1
}

# Setup chroot
if [ ! -d "$CHRDIR" ]; then
	setup_chroot || ( rm -rf "$CHRDIR" && exit 1 )
fi

# Install mandatory packages
"${CURDIR}/llchroot.sh" "$WDIR" apt-get install --yes ubuntu-standard casper lupin-casper discover laptop-detect os-prober linux-generic || exit 1
"${CURDIR}/llchroot.sh" "$WDIR" apt-get install --yes --no-install-recommends network-manager || exit 1

# Setup iso creation
mkdir -p "$ISODIR"/{casper,isolinux,install} || exit 1

# Setup image creation
mkdir -p "$IMGDIR/mnt" || exit 1
touch "$IMGDIR/loop" || exit 1

# Generate default boot instructions
printf '
************************************************************************

This is an Ubuntu Remix Live CD.

For the default live system, enter "live".  To run memtest86+, enter "memtest"

************************************************************************
' > "$ISODIR/isolinux/isolinux.txt"

# Generate default boot config
printf 'DEFAULT live

LABEL live
  menu label ^Start or install Ubuntu Remix
  kernel /casper/vmlinuz
  append  file=/cdrom/preseed/ubuntu.seed boot=casper initrd=/casper/initrd.lz quiet splash --
LABEL check
  menu label ^Check CD for defects
  kernel /casper/vmlinuz
  append  boot=casper integrity-check initrd=/casper/initrd.lz quiet splash --
LABEL memtest
  menu label ^Memory test
  kernel /install/memtest
  append -
LABEL hd
  menu label ^Boot from first hard disk
  localboot 0x80
  append -
DISPLAY isolinux.txt
TIMEOUT 300
PROMPT 1 

#prompt flag_val
# 
# If flag_val is 0, display the "boot:" prompt 
# only if the Shift or Alt key is pressed,
# or Caps Lock or Scroll lock is set (this is the default).
# If  flag_val is 1, always display the "boot:" prompt.
#  http://linux.die.net/man/1/syslinux   syslinux manpage
' > "$ISODIR/isolinux/isolinux.cfg"

# Create diskdefines
printf '#define DISKNAME  Ubuntu Remix
#define TYPE  binary
#define TYPEbinary  1
#define ARCH  i386
#define ARCHi386  1
#define DISKNUM  1
#define DISKNUM1  1
#define TOTALNUM  0
#define TOTALNUM0  1
' > "$ISODIR/README.diskdefines"

touch "$ISODIR/ubuntu"
mkdir "$ISODIR/.disk"
touch "$ISODIR/.disk/base_installable"
echo 'full_cd/single' > "$ISODIR/.disk/cd_type"
echo 'Ubuntu Remix' > "$ISODIR/.disk/info"
echo 'http://www.psislab.com' > "$ISODIR/.disk/release_notes_url"

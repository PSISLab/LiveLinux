#!/bin/bash

CURDIR="$(cd `dirname $0` && pwd)"

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

function usage
{
	CMD="$1"
	
	if [ -z "$CMD" ]; then
		echo "Usage: $0 <command> <target> [command args...]"
		echo ""
		echo "	Commands :"
		echo "		$(usage_help)"
		echo "		$(usage_setup)"
		echo "		$(usage_chroot)"
		echo "		$(usage_release)"
	elif [ "$(type -t usage_$CMD)" == "function" ]; then
		echo "Usage: $0 <target> $(usage_$CMD)"
	fi
}

function cmd_help
{
	CMD="$1"
	
	if [ -n "$CMD" ]; then
		if [ "$(type -t help_$CMD)" == "function" ]; then
			help_$CMD
		else
			usage "$CMD"
		fi
	else
		usage help
	fi
}

function usage_help
{
	echo "help [command]"
}

function help_help
{
	echo "Display this help message"
}

function cmd_setup
{
	# Check target directory
	if [ -f "$TARGET" ] || [ -d "$TARGET" ]; then
		echo "Target directory '$TARGET' already exists" && exit 1
	fi
	
	# Create target directory
	mkdir -p "$TARGET" || exit 1
	echo "0.0.1" > "$TARGET/version" || exit 2
	
	# Bootstrap Ubuntu with same arch and release
	mkdir -p "$CHRDIR" || return 2
	RELEASE="$(lsb_release -sc)" || return 2
	DEBIAN_FRONTEND=noninteractive debootstrap "$RELEASE" "$CHRDIR" || return 2
	
	# Copy apt sources.list configuration
	cp "/etc/apt/sources.list" "$CHRDIR/etc/apt/sources.list" || return 2

	# Install mandatory packages
	"$0" chroot "$TARGET" DEBIAN_FRONTEND=noninteractive  apt-get install --yes ubuntu-standard casper lupin-casper discover laptop-detect os-prober linux-generic || exit 2
	"$0" chroot "$TARGET" DEBIAN_FRONTEND=noninteractive  apt-get install --yes --no-install-recommends network-manager || exit 2

	# Setup image creation
	mkdir -p "$IMGDIR"/{casper,isolinux,install} || exit 2
	
	# Setup release storage
	mkdir -p "$RELDIR" || exit 2

	# Setup release creation
	mkdir -p "$FACDIR/mnt" || exit 2
	touch "$FACDIR/loop" || exit 2

	# Generate default boot instructions
	printf '
************************************************************************

This is an Ubuntu Remix Live CD.

For the default live system, enter "live".  To run memtest86+, enter "memtest"

************************************************************************
	' > "$IMGDIR/isolinux/isolinux.txt" || return 2

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
	' > "$IMGDIR/isolinux/isolinux.cfg" || return 2

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
	' > "$IMGDIR/README.diskdefines" || return 2

	touch "$IMGDIR/ubuntu" || return 2
	mkdir "$IMGDIR/.disk" || return 2
	touch "$IMGDIR/.disk/base_installable" || return 2
	echo 'full_cd/single' > "$IMGDIR/.disk/cd_type" || return 2
	echo 'Ubuntu Remix' > "$IMGDIR/.disk/info" || return 2
	echo 'http://www.psislab.com' > "$IMGDIR/.disk/release_notes_url" || return 2
}

function error_setup
{
	case $1 in
		2)	rm -r "$TARGET"
	esac
	
	return 1
}

function usage_setup
{
	echo "setup [-f|--force]"
}

function cmd_chroot
{
	local CHRSCRIPT="/tmp/load-chroot.sh"
	
	# Bind /dev to chroot environment
	mount --bind "/dev" "$CHRDIR/dev" || return 1
	
	# Copy network configuration
	cp "$CHRDIR/etc/hosts" "$CHRDIR/etc/hosts~" || return 2
	cp "/etc/hosts" "$CHRDIR/etc/hosts" || return 2
	cp "/etc/resolv.conf" "$CHRDIR/etc/resolv.conf" || return 2
	
	# Write script to chroot
	printf '
trap "" 2

# Mount /proc, /sys and /dev/pts
mount none -t proc /proc || return 1
mount none -t sysfs /sys || return 1
mount none -t devpts /dev/pts || return 1

# Export some environment variables
export HOME=/root
export LC_ALL=C

# Add PSISLab PPA Key
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B6AC35BA || return 1

# Install dbus if needed
dpkg -s dbus >/dev/null || ( apt-get update && apt-get install --yes dbus ) || return 1

# Create new machine ID
dbus-uuidgen > /var/lib/dbus/machine-id || return 1

# Create diversion
dpkg-divert --local --rename --add /sbin/initctl && ln -s /bin/true /sbin/initctl || return 1

# Load shell or command
trap 2
if [ $# -gt 0 ]; then
	$*
else
	${SHELL} -i
fi

CMDRESULT=$?
CLEANERROR=0
trap "" 2

# Remove machine ID
rm /var/lib/dbus/machine-id || CLEANERROR=1

# Remove diversion
rm /sbin/initctl && dpkg-divert --rename --remove /sbin/initctl || CLEANERROR=1

# Clean up
apt-get clean || CLEANERROR=1
rm -rf /tmp/* || CLEANERROR=1
rm /etc/resolv.conf || CLEANERROR=1
mv "/etc/hosts~" "/etc/hosts" || CLEANERROR=1

# Umount filesystem
umount -lf /proc || CLEANERROR=1
umount -lf /sys || CLEANERROR=1
umount -lf /dev/pts || CLEANERROR=1
trap 2

if [ $CMDRESULT -ne 0 ]; then
	return 2
elif [ $CLEANERROR -ne 0 ]; then
	return 1
else
	return 0
fi
' > "$CHRDIR$CHRSCRIPT" || return 2
	chmod +x "$CHRDIR$CHRSCRIPT" || return 2
	
	# Load chroot
	chroot "$CHRDIR" "$CHRSCRIPT" $*
	local CMDRESULT=$?
	
	# Unbind /dev from chroot envionment
	umount -l "$CHRDIR/dev" || return 1
	
	return $(expr $CMDRESULT + 4)
}

function error_chroot
{
	if [ $1 -ge 4 ]; then
		return $(expr $1 - 4)
	fi
	
	case $1 in
		2)	umount -l "CHRDIR/dev"
	esac
	
	return 1
}

function usage_chroot
{
	echo "chroot [cmd [args...]]"
}

function release_iso
{
	cp "$CHRDIR/boot/vmlinuz-"* "$IMGDIR/casper/vmlinuz" || exit 1
	cp "$CHRDIR/boot/initrd.img-"* "$IMGDIR/casper/initrd.lz" || exit 1
	cp "/usr/lib/syslinux/isolinux.bin" "$IMGDIR/isolinux/isolinux.bin" || exit 1
	cp "/boot/memtest86+.bin" "$IMGDIR/install/memtest" || exit 1

	# Create manifest
	chroot "$CHRDIR" dpkg-query -W --showformat='${Package} ${Version}\n' > "$IMGDIR/casper/filesystem.manifest" || exit 1

	# Compress the chroot
	mksquashfs "$CHRDIR" "$IMGDIR/casper/filesystem.squashfs" -noappend -e boot || exit 1
	printf $(du -sx --block-size=1 "$CHRDIR" | cut -f1) > "$IMGDIR/casper/filesystem.size" || exit 1

	# Calculate MD5
	(cd "$IMGDIR" && find . -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > "md5sum.txt") || exit 1

	# Create ISO
	cd "$IMGDIR" || exit 1
	mkisofs -r -V "UbuntuRemix" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o "$RELDIR/ubuntu-remix.iso" .
	cd "$CURDIR"
}

function release_img
{
	cd "$FACDIR" || return 1
	dd if=/dev/zero of=loop bs=1 count=1 seek=700M || return 1
	mkfs.ext2 -L rescue -m 0 loop || return 1

	ln -s "$IMGDIR" tmp || return 1
	mount -o loop loop mnt || return 1

	cp -a tmp/* mnt/ || return 1

	cd mnt || return 1
	mkdir boot || return 1
	mv isolinux boot/extlinux || return 1
	mv boot/extlinux/isolinux.cfg boot/extlinux/extlinux.conf || return 1
	extlinux --install boot/extlinux/ || return 1
	cd .. || return 1
	umount mnt || return 1
	rm tmp || return 1

	gzip -c loop > "$RELDIR/ubuntu-remix.img.gz" || return 1
}

function cmd_release
{
	release_iso
	release_img
}

function usage_release
{
	echo "release [--iso] [--img] [[-m|--minor]|[-M|--major]]"
}

# ------------------------------------------------------------------------ #



# ------------------------------------------------------------------------ #

CMD="$1"; shift
TARGET="$(readlink -m "$1")"; shift

CHRDIR="$TARGET/root"
IMGDIR="$TARGET/image"
FACDIR="$TARGET/factory"
RELDIR="$TARGET/releases"

if [ -z "$CMD" ]; then
	usage
	exit 1
elif [ -z "$TARGET" ]; then
	usage
	exit 1
elif [ "$(type -t cmd_$CMD)" == "function" ]; then
	cmd_$CMD $*
	RETVAL=$?
	
	if [ $RETVAL -ne 0 ] && [ "$(type -t error_$CMD)" == "function" ]; then
		error_$CMD $RETVAL
		RETVAL=$?
	fi
	
	exit $RETVAL
else
	echo "Command invalid: $CMD"
	echo
	
	usage
	exit 1
fi

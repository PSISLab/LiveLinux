#!/bin/bash

CURDIR="$(cd `dirname $0` && pwd)"

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

TARGET="$(readlink -m "$1")"; shift

CHRDIR="$TARGET/root"
IMGDIR="$TARGET/image"
FACDIR="$TARGET/factory"
RELDIR="$TARGET/releases"
CNFDIR="$TARGET/conf"

function self
{
	local CMD="$1"; shift
	
	if [ -z "$TARGET" ]; then
		usage
		return 1
	elif [ -z "$CMD" ]; then
		usage
		return 1
	elif [ "$(type -t cmd_$CMD)" == "function" ]; then
		cmd_$CMD $*
		RETVAL=$?
		
		if [ $RETVAL -ne 0 ] && [ "$(type -t error_$CMD)" == "function" ]; then
			error_$CMD $RETVAL
			RETVAL=$?
		fi
		
		return $RETVAL
	else
		echo "Command invalid: $CMD"
		echo
		
		usage
		return 1
	fi
}

function usage
{
	CMD="$1"
	
	if [ -z "$CMD" ]; then
		echo "Usage: $0 <target> <command> [command args...]"
		echo ""
		echo "	Commands :"
		echo "		help $(usage_help)"
		echo "		setup $(usage_setup)"
		echo "		chroot $(usage_chroot)"
		echo "		release $(usage_release)"
		echo "		write $(usage_write)"
		echo "		set $(usage_set)"
		echo "		unset $(usage_unset)"
		echo "		get $(usage_get)"
	elif [ "$(type -t usage_$CMD)" == "function" ]; then
		echo "Usage: $0 <target> $CMD $(usage_$CMD)"
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
	echo "[command]"
}

function help_help
{
	echo "Display this help message"
}

function cmd_setup
{
	# Check target directory
	if [ -f "$TARGET" ] || [ -d "$TARGET" ]; then
		echo "Target directory '$TARGET' already exists" && return 1
	fi
	
	# Create target directory
	mkdir -p "$TARGET" || return 1
	mkdir -p "$CNFDIR" || return 1
	cmd_set version "0.0.0" || return 2
	
	# Bootstrap Ubuntu with same arch and release
	mkdir -p "$CHRDIR" || return 2
	RELEASE="$(lsb_release -sc)" || return 2
	DEBIAN_FRONTEND=noninteractive debootstrap "$RELEASE" "$CHRDIR" || return 2
	
	# Copy apt sources.list configuration
	cp "/etc/apt/sources.list" "$CHRDIR/etc/apt/sources.list" || return 2

	# Install mandatory packages
	echo "#!/bin/bash
DEBIAN_FRONTEND=noninteractive  apt-get install --yes ubuntu-standard casper lupin-casper discover laptop-detect os-prober linux-generic || exit 1
DEBIAN_FRONTEND=noninteractive  apt-get install --yes --no-install-recommends network-manager || exit 1
" > "$CHRDIR/tmp/init-chroot.sh" || return 2
	chmod +x "$CHRDIR/tmp/init-chroot.sh" || return 2
	cmd_chroot /tmp/init-chroot.sh || error_chroot $? || return 2

	# Setup image creation
	mkdir -p "$IMGDIR"/{casper,isolinux,install} || return 2
	
	# Setup release storage
	mkdir -p "$RELDIR" || return 2

	# Setup release creation
	mkdir -p "$FACDIR/mnt" || return 2
	touch "$FACDIR/loop" || return 2

	# Generate default boot instructions
	printf "Starting $(cmd_get title)...
" > "$IMGDIR/isolinux/isolinux.txt" || return 2

	# Generate default boot config
	printf 'DEFAULT boot
LABEL boot
  menu label ^Start $(cmd_get title)
  kernel /casper/vmlinuz
  append  file=/cdrom/preseed/ubuntu.seed boot=casper initrd=/casper/initrd.lz quiet splash --
LABEL check
  menu label ^Check disk for defects
  kernel /casper/vmlinuz
  append  boot=casper integrity-check initrd=/casper/initrd.lz quiet splash --
LABEL memtest
  menu label ^Memory test
  kernel /install/memtest
  append -

DISPLAY isolinux.txt
TIMEOUT 30
PROMPT 0 
' > "$IMGDIR/isolinux/isolinux.cfg" || return 2

	# Create diskdefines
	printf "#define DISKNAME  $(cmd_get title)
#define TYPE  binary
#define TYPEbinary  1
#define ARCH  amd64
#define ARCHamd64  1
#define ARCHi386  0
#define DISKNUM  1
#define DISKNUM1  1
#define TOTALNUM  0
#define TOTALNUM0  1
" > "$IMGDIR/README.diskdefines" || return 2

	touch "$IMGDIR/ubuntu" || return 2
	mkdir "$IMGDIR/.disk" || return 2
	#touch "$IMGDIR/.disk/base_installable" || return 2
	echo 'full_cd/single' > "$IMGDIR/.disk/cd_type" || return 2
	echo "$(cmd_get title)" > "$IMGDIR/.disk/info" || return 2
	#echo 'http://www.psislab.com' > "$IMGDIR/.disk/release_notes_url" || return 2
}

function usage_setup
{
	echo ""
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
	echo "[cmd [args...]]"
}

function cmd_release
{
	local iso=no
	local img=no
	
	local version="$(cmd_get version)" || return 1
	local major="$(echo "$version" | awk -F. '{print $1}')" || return 1
	local minor="$(echo "$version" | awk -F. '{print $2}')" || return 1
	local build="$(echo "$version" | awk -F. '{print $3}')" || return 1
	version=
	let build++
	
	while [ $# -gt 0 ]; do
		case "$1" in
			--iso)	iso=yes ;;
			--img)	img=yes ;;
			
			--minor|-m)
					let minor++
					build=1
					;;
			
			--major|-M)
					let major++
					minor=0
					build=1
					;;
			
			--version|-v)
					shift
					version="$1"
					;;
		esac
		shift
	done
	
	if [ -z "$version" ]; then
		version="$major.$minor.$build"
	fi
	cmd_set version "$version" || return 1
	
	# Build vmlinuz
	printf "# Auto-generated file
export USERNAME="$(cmd_get username)"
export USERFULLNAME="$(cmd_get username-full)"
export HOST="$(cmd_get hostname)"
export BUILD_SYSTEM="$(cmd_get title)"
" > "$CHRDIR/etc/casper.conf" || return 1
	self chroot depmod -a "$(cmd_get kernel)" || return 1
	self chroot update-initramfs -u -k "$(cmd_get kernel)" || return 1
	
	cp "$CHRDIR/boot/vmlinuz-"* "$IMGDIR/casper/vmlinuz" || return 1
	cp "$CHRDIR/boot/initrd.img-"* "$IMGDIR/casper/initrd.lz" || return 1
	cp "/usr/lib/syslinux/isolinux.bin" "$IMGDIR/isolinux/isolinux.bin" || return 1
	cp "/boot/memtest86+.bin" "$IMGDIR/install/memtest" || return 1

	# Create manifest
	chroot "$CHRDIR" dpkg-query -W --showformat='${Package} ${Version}\n' > "$IMGDIR/casper/filesystem.manifest" || return 1

	# Compress the chroot
	mksquashfs "$CHRDIR" "$IMGDIR/casper/filesystem.squashfs" -noappend -e boot || return 1
	printf $(du -sx --block-size=1 "$CHRDIR" | cut -f1) > "$IMGDIR/casper/filesystem.size" || return 1

	# Calculate MD5
	(cd "$IMGDIR" && find . -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > "md5sum.txt") || return 1
	
	if [ "$iso" == "yes" ]; then
		# Create ISO
		mkisofs -r -V "UbuntuRemix" -cache-inodes -J -l -b "$IMGDIR/isolinux/isolinux.bin" -c "$IMGDIR/isolinux/boot.cat" -no-emul-boot -boot-load-size 4 -boot-info-table -o "$RELDIR/ubuntu-remix-$version.iso" "$IMGDIR" || return 1
	fi
	
	if [ "$img" == "yes" ]; then
		# Find free loopback device
		local loop_device=
		for loop_device in $(ls /dev/loop[0-9]); do
			losetup "$loop_device" || break
		done
		
		if [ -n "$loop_device" ]; then
			ERROR_RELEASE_loop_device="$loop_device"
		else
			return 1
		fi

		dd if=/dev/zero of="$FACDIR/diskpart.sys" bs=1 count=0 seek=350M || return 1
		losetup "$loop_device" "$FACDIR/diskpart.sys" || return 1
		mkfs.ext2 -L "UbuntuRemix" -m 1 "$loop_device" || return 2

		mount "$loop_device" "$FACDIR/mnt" || return 2

		cp -a "$IMGDIR/"* "$FACDIR/mnt/" || return 3

		mkdir "$FACDIR/mnt/boot" || return 3
		mv "$FACDIR/mnt/isolinux" "$FACDIR/mnt/boot/extlinux" || return 3
		mv "$FACDIR/mnt/boot/extlinux/isolinux.cfg" "$FACDIR/mnt/boot/extlinux/extlinux.conf" || return 3
		extlinux --install "$FACDIR/mnt/boot/extlinux/" || return 1
		umount "$loop_device" || return 2

		gzip -c "$loop_device" > "$RELDIR/ubuntu-remix-$version.img.gz" || return 2
		losetup -d "$loop_device" || return 1
	fi
}

function error_release
{
	case $1 in
		3)	umount "$ERROR_RELEASE_loop_device"
			losetup -d "$ERROR_RELEASE_loop_device"
			;;
		
		2)	losetup -d "$ERROR_RELEASE_loop_device"
			;;
	esac
	
	return 1
}

function usage_release
{
	echo "[--iso] [--img] [[-m|--minor]|[-M|--major]|[-v|--version <major.minor.build>]"
}

function cmd_write
{
	local device="$1"
	local version="$(cmd_get version)"
	
	zcat "$RELDIR/ubuntu-remix-$version.img.gz" > "$device"
}

function usage_write
{
	echo "[-v|--version <version>] device"
}

function cmd_set
{
	local var="$1"
	local value="$2"
	
	if [ "$(type -t set_$var)" == "function" ]; then
		set_$var "$value" || return 1
	else
		echo "$value" > "$CNFDIR/$var" || return 1
	fi
}

function usage_set
{
	echo "<var> <value>"
}

function cmd_unset
{
	local var="$1"
	
	if [ "$(type -t unset_$var)" == "function" ]; then
		unset_$var || return 1
	elif [ -f "$CNFDIR/$var" ]; then
		rm "$CNFDIR/$var" || return 1
	fi
}

function usage_unset
{
	echo "<var>"
}

function cmd_get
{
	local var="$1"
	
	if [ "$(type -t get_$var)" == "function" ]; then
		get_$var || return 1
	elif [ -f "$CNFDIR/$var" ]; then
		cat "$CNFDIR/$var" || return 1
	else
		case "$var" in
			version)		echo "0.0.0" || return 1 ;;
			title)			echo "LinuxLive" || return 1 ;;
			username)		echo "admin" || return 1 ;;
			username-full)	echo "Administrator" || return 1 ;;
			hostname)		echo "linuxlive" || return 1 ;;
			
			*)	echo "Unknown var '$var'"
				return 1
		esac
	fi
}

function usage_get
{
	echo "<var>"
}

# ------------------------------------------------------------------------ #

function set_version
{
	local value="$(echo "$1" | grep -x "[[:digit:]]\.[[:digit:]]\.[[:digit:]]")"
	
	if [ -n "$value" ]; then
		echo "$value" > "$CNFDIR/version" || return 1
	else
		return 1
	fi
}

function get_kernel
{
	echo "$(cd $CHRDIR/boot && ls vmlinuz-* | sed 's@vmlinuz-@@')"
}

# ------------------------------------------------------------------------ #

self $*
exit $?

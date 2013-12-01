#!/bin/bash
#
# This file is part of LiveLinuxMaker,
# Copyright 2013 Jonathan GIRARD-YEL <jonathan.girardyel@free.fr>
#
# LiveLinuxMaker is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# LiveLinuxMaker is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with LiveLinuxMaker.  If not, see <http://www.gnu.org/licenses/>.

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
		
		if [ $RETVAL -ne 0 ]; then
			display error "Failed with error $RETVAL"
		fi
		
		return $RETVAL
	else
		display error "Command invalid: $CMD"
		echo
		
		usage
		return 1
	fi
}

function format
{
	# Based on http://misc.flogisoft.com/bash/tip_colors_and_formatting
	
	local mode=auto
	local code=
	local sep=
	
	echo -ne '\e['
	while [ $# -gt 0 ]; do
		case "$1" in
			default)
				[ "$mode" == "auto" ] && code=0
				[ "$mode" == "reset" ] && code=0
				[ "$mode" == "fg" ] && code=39
				[ "$mode" == "bg" ] && code=49
				;;
			
			reset)				mode=reset ;;
			fg|foreground|text)	mode=fg ;;
			bg|background)		mode=bg ;;
			
			b|bold)			[ "$mode" == "reset" ] && code=21 || code=1; mode=auto ;;
			dim)			[ "$mode" == "reset" ] && code=22 || code=2; mode=auto ;;
			u|underlined)	[ "$mode" == "reset" ] && code=24 || code=4; mode=auto ;;
			blink)			[ "$mode" == "reset" ] && code=25 || code=5; mode=auto ;;
			reverse)		[ "$mode" == "reset" ] && code=27 || code=7; mode=auto ;;
			hidden)			[ "$mode" == "reset" ] && code=28 || code=8; mode=auto ;;
			
			black)			[ "$mode" == "bg" ] && code=40 || code=30 ;;
			white)			[ "$mode" == "bg" ] && code=107 || code=97 ;;
			
			red)			[ "$mode" == "bg" ] && code=41 || code=31 ;;
			green)			[ "$mode" == "bg" ] && code=42 || code=32 ;;
			yellow)			[ "$mode" == "bg" ] && code=43 || code=33 ;;
			blue)			[ "$mode" == "bg" ] && code=44 || code=34 ;;
			magenta)		[ "$mode" == "bg" ] && code=45 || code=35 ;;
			cyan)			[ "$mode" == "bg" ] && code=46 || code=36 ;;
			
			light-gray)		[ "$mode" == "bg" ] && code=47 || code=37 ;;
			dark-gray)		[ "$mode" == "bg" ] && code=100 || code=90 ;;
			
			light-red)		[ "$mode" == "bg" ] && code=101 || code=91 ;;
			light-green)	[ "$mode" == "bg" ] && code=102 || code=92 ;;
			light-yellow)	[ "$mode" == "bg" ] && code=103 || code=93 ;;
			light-blue)		[ "$mode" == "bg" ] && code=104 || code=94 ;;
			light-magenta)	[ "$mode" == "bg" ] && code=105 || code=95 ;;
			light-cyan)		[ "$mode" == "bg" ] && code=106 || code=96 ;;
		esac
		
		if [ -n "$code" ]; then
			echo -n "$sep$code" && sep=";"
			[ $code -eq 0 ] && break
		fi
		
		shift
	done
	echo -n 'm'
}

function display
{
	local type="$1"
	shift
	
	case "$type" in
		step)		format cyan && echo "* $*" ;;
		success)	format bold green && echo "> $*" ;;
		error)		format bold white bg red && echo "! $*  " ;;
	esac
	
	format default
	format dark-gray
}

function usage
{
	CMD="$1"
	
	format default
	if [ -z "$CMD" ]; then
		echo "Usage: $0 <target> <command> [command args...]"
		echo ""
		echo "	Commands :"
		echo "		help $(usage_help)"
		echo "		setup $(usage_setup)"
		echo "		chroot $(usage_chroot)"
		echo "		release $(usage_release)"
		echo "		releases $(usage_releases)"
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
	display step "Check target directory"
	if [ -f "$TARGET" ] || [ -d "$TARGET" ]; then
		display error "Target directory '$TARGET' already exists" && return 1
	fi
	
	display step "Create target directory"
	mkdir -p "$TARGET" || return 1
	mkdir -p "$CNFDIR" || return 1
	cmd_set version "0.0.0" || return 2
	
	display step "Bootstrap Ubuntu with same arch and release as host"
	mkdir -p "$CHRDIR" || return 2
	RELEASE="$(lsb_release -sc)" || return 2
	DEBIAN_FRONTEND=noninteractive debootstrap "$RELEASE" "$CHRDIR" || return 2
	
	display step "Copy apt sources.list configuration"
	cp "/etc/apt/sources.list" "$CHRDIR/etc/apt/sources.list" || return 2

	display step "Install mandatory packages in chroot"
	printf '#!/bin/bash
echo -n '$(format default)'
echo -n '$(format dark-gray)'
DEBIAN_FRONTEND=noninteractive  apt-get install --yes ubuntu-standard casper lupin-casper discover laptop-detect os-prober linux-generic || exit 1
DEBIAN_FRONTEND=noninteractive  apt-get install --yes --no-install-recommends network-manager || exit 1
' > "$CHRDIR/tmp/init-chroot.sh" || return 2
	chmod +x "$CHRDIR/tmp/init-chroot.sh" || return 2
	cmd_chroot /tmp/init-chroot.sh || error_chroot $? || return 2
	rm "$CHRDIR/usr/share/initramfs-tools/scripts/casper-bottom/25adduser" || return 2

	display step "Setup image directory"
	mkdir -p "$IMGDIR"/{casper,isolinux,install} || return 2
	
	display step "Setup release storage directory"
	mkdir -p "$RELDIR" || return 2

	display step "Setup release creation directory"
	mkdir -p "$FACDIR/mnt" || return 2
	touch "$FACDIR/loop" || return 2

	display step "Generate default isolinux"
	touch "$IMGDIR/ubuntu" || return 2
	mkdir "$IMGDIR/.disk" || return 2
	
	display success "Done"
}

function usage_setup
{
	echo ""
}

function cmd_chroot
{
	local CHRSCRIPT="/tmp/load-chroot.sh"
	
	display step "Bind /dev to chroot environment"
	mount --bind "/dev" "$CHRDIR/dev" || return 1
	
	display step "Copy network configuration"
	cp "$CHRDIR/etc/hosts" "$CHRDIR/etc/hosts~" || return 2
	cp "/etc/hosts" "$CHRDIR/etc/hosts" || return 2
	cp "/etc/resolv.conf" "$CHRDIR/etc/resolv.conf" || return 2
	
	display step "Write init script to chroot"
	printf '#!/bin/bash
trap "" 2

# Mount /proc, /sys and /dev/pts
mount none -t proc /proc || exit 1
mount none -t sysfs /sys || exit 1
mount none -t devpts /dev/pts || exit 1

# Export some environment variables
export HOME=/root
export LC_ALL=C

# Add PSISLab PPA Key
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B6AC35BA || exit 1

# Install dbus if needed
dpkg -s dbus >/dev/null || ( apt-get update && apt-get install --yes dbus ) || exit 1

# Create new machine ID
dbus-uuidgen > /var/lib/dbus/machine-id || exit 1

# Create diversion
dpkg-divert --local --rename --add /sbin/initctl && ln -s /bin/true /sbin/initctl || exit 1

# Load shell or command
trap 2
echo -n '$(format default)'
if [ $# -gt 0 ]; then
	$*
else
	${SHELL} -i
fi
echo -n '$(format default)'
echo -n '$(format dark-gray)'

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
	exit 2
elif [ $CLEANERROR -ne 0 ]; then
	exit 1
else
	exit 0
fi
' > "$CHRDIR$CHRSCRIPT" || return 2
	chmod +x "$CHRDIR$CHRSCRIPT" || return 2
	
	display step "Load chroot"
	chroot "$CHRDIR" "$CHRSCRIPT" $*
	local CMDRESULT=$?
	
	display step "Unbind /dev from chroot envionment"
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
	local write_device=
	
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
			--write)
					shift
					write_device="$1"
					;;
			
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
	display step "Set version to $version"
	cmd_set version "$version" || return 1

	display step "Generate isolinux boot config"
	echo "Starting $(cmd_get title)..." > "$IMGDIR/isolinux/isolinux.txt" || return 1
	echo "DEFAULT boot
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
" > "$IMGDIR/isolinux/isolinux.cfg" || return 1

	display step "Create diskdefines"
	echo "#define DISKNAME  $(cmd_get title)
#define TYPE  binary
#define TYPEbinary  1
#define ARCH  amd64
#define ARCHamd64  1
#define ARCHi386  0
#define DISKNUM  1
#define DISKNUM1  1
#define TOTALNUM  0
#define TOTALNUM0  1
" > "$IMGDIR/README.diskdefines" || return 1

	display step "Create ISO disk infos"
	#touch "$IMGDIR/.disk/base_installable" || return 1
	echo "full_cd/single" > "$IMGDIR/.disk/cd_type" || return 1
	echo "$(cmd_get title)" > "$IMGDIR/.disk/info" || return 1
	#echo 'http://www.psislab.com' > "$IMGDIR/.disk/release_notes_url" || return 1
	
	if [ -n "$(self get autologin)" ]; then
		display step "Check autologin username"
		if ! grep -x "^$(self get autologin):.*$" "$CHRDIR/etc/shadow" ; then
			display error "Username '$(self get autologin)' does not exists"
			return 1
		fi
	fi
	
	display step "Build vmlinuz"
	printf "# File generated by llm, do not edit
export USERNAME="$(self get autologin)"
export USERFULLNAME=""
export HOST="$(cmd_get hostname)"
export BUILD_SYSTEM="$(cmd_get title)"
" > "$CHRDIR/etc/casper.conf" || return 1
	self chroot depmod -a "$(cmd_get kernel)" || return 1
	self chroot update-initramfs -u -k "$(cmd_get kernel)" || return 1
	
	cp "$CHRDIR/boot/vmlinuz-$(cmd_get kernel)" "$IMGDIR/casper/vmlinuz" || return 1
	cp "$CHRDIR/boot/initrd.img-$(cmd_get kernel)" "$IMGDIR/casper/initrd.lz" || return 1
	cp "/usr/lib/syslinux/isolinux.bin" "$IMGDIR/isolinux/isolinux.bin" || return 1
	cp "/boot/memtest86+.bin" "$IMGDIR/install/memtest" || return 1

	display step "Create manifest"
	chroot "$CHRDIR" dpkg-query -W --showformat='${Package} ${Version}\n' > "$IMGDIR/casper/filesystem.manifest" || return 1

	display step "Compress filesystem into squashfs"
	mksquashfs "$CHRDIR" "$IMGDIR/casper/filesystem.squashfs" -noappend -e boot || return 1
	printf $(du -sx --block-size=1 "$CHRDIR" | cut -f1) > "$IMGDIR/casper/filesystem.size" || return 1
	
	display step "Calculate MD5"
	(cd "$IMGDIR" && find . -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > "md5sum.txt") || return 1
	
	if [ "$iso" == "yes" ]; then
		display step "Create ISO"
		mkisofs -r -V "$(cmd_get title)" -cache-inodes -J -l -b "$IMGDIR/isolinux/isolinux.bin" -c "$IMGDIR/isolinux/boot.cat" -no-emul-boot -boot-load-size 4 -boot-info-table -o "$RELDIR/$(cmd_get title)-$version.iso" "$IMGDIR" || return 1
	fi
	
	if [ "$img" == "yes" ]; then
		display step "Find free loopback device"
		local loop_device=
		for loop_device in $(ls /dev/loop[0-9]); do
			losetup "$loop_device" || break
		done
		
		if [ -n "$loop_device" ]; then
			ERROR_RELEASE_loop_device="$loop_device"
		else
			return 1
		fi
		
		display step "Calculate system partition size"
		local size="$(du -m "$IMGDIR/casper/filesystem.squashfs" | awk '{print $1}')" || return 1
		let size+=50

		display step "Create system partition"
		dd if=/dev/zero of="$FACDIR/diskpart.sys" bs=1 count=0 seek=${size}M || return 1
		losetup "$loop_device" "$FACDIR/diskpart.sys" || return 1

		display step "Format system partition"
		mkfs.ext2 -L "$(cmd_get title)" -m 1 "$loop_device" || return 2

		display step "Copy system files"
		mount "$loop_device" "$FACDIR/mnt" || return 2
		cp -a "$IMGDIR/"* "$FACDIR/mnt/" || return 3

		display step "Setup extlinux"
		mkdir "$FACDIR/mnt/boot" || return 3
		mv "$FACDIR/mnt/isolinux" "$FACDIR/mnt/boot/extlinux" || return 3
		mv "$FACDIR/mnt/boot/extlinux/isolinux.cfg" "$FACDIR/mnt/boot/extlinux/extlinux.conf" || return 3
		extlinux --install "$FACDIR/mnt/boot/extlinux/" || return 1
		umount "$loop_device" || return 2

		display step "Export image to $RELDIR/$(cmd_get title)-$version.img.gz"
		gzip -c "$loop_device" > "$RELDIR/$(cmd_get title)-$version.img.gz" || return 2
		losetup -d "$loop_device" || return 1
		
		if [ -n "$write_device" ]; then
			self write "$write_device" || return 1
		else
			display success "Done"
		fi
	else
		display success "Done"
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
	echo "[--iso] [--img [--write <device>]] [[-m|--minor]|[-M|--major]|[-v|--version <major.minor.build>]"
}

function cmd_releases
{
	local release=
	
	for release in $(ls "$RELDIR"); do
		echo "$release" | grep -o "[[:digit:]]\+.[[:digit:]]\+.[[:digit:]]\+.\(iso\|img.gz\)$"
	done
}

function usage_releases
{
	echo "releases"
}

function cmd_write
{
	local device="$1"
	local version="$(cmd_get version)"
	
	display step "Check device $device"
	if [ ! -b "$device" ]; then
		display error "Device '$device' does not exists or is not a block device"
		return 1
	elif mount | grep "^$device on .*$"; then
		display error "Device '$device' is already mounted"
		return 1
	fi
	
	display step "Check source file"
	if [ ! -f "$RELDIR/$(cmd_get title)-$version.img.gz" ]; then
		display error "No image found for the version $version"
		return 1
	fi
	
	display step "Write image $version to '$device'"
	zcat "$RELDIR/$(cmd_get title)-$version.img.gz" > "$device" || return 1
	
	display success "Done"
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
			hostname)		echo "linuxlive" || return 1 ;;
			autologin)		echo "" || return 1 ;;
			
			*)	display error "Unknown var '$var'"
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
	local value="$(echo "$1" | grep -x '[0-9]\+\.[0-9]\+\.[0-9]\+')"
	
	if [ -n "$value" ]; then
		echo "$value" > "$CNFDIR/version" || return 1
	else
		display error "Bad format for version: '$1', must be a sequence of 3 dot-separated digits"
		return 1
	fi
}

function set_kernel
{
	display error "This var is read only"
	return 1
}

function unset_kernel
{
	display_error "This var is read only"
	return 1
}

function get_kernel
{
	echo "$(cd $CHRDIR/boot && ls vmlinuz-* | sed 's@vmlinuz-@@')"
}

# ------------------------------------------------------------------------ #

format default
self $*
format default
exit $?

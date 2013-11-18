#!/bin/bash

SELFSCRIPT="$0"

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

function load_chroot
{
	CHRDIR="$1"; shift
	CHRSCRIPT="/tmp/load-chroot.sh"
	
	# Bind /dev to chroot environment
	mount --bind "/dev" "$CHRDIR/dev" || return 1
	
	# Copy network configuration
	cp "$CHRDIR/etc/hosts" "$CHRDIR/etc/hosts~"
	cp "/etc/hosts" "$CHRDIR/etc/hosts"
	cp "/etc/resolv.conf" "$CHRDIR/etc/resolv.conf"
	
	# Copy init script to chroot
	cp "$SELFSCRIPT" "$CHRDIR$CHRSCRIPT" || return 1
	chmod +x "$CHRDIR$CHRSCRIPT" || return 1
	
	# Load chroot
	chroot "$CHRDIR" "$CHRSCRIPT" --inside-chroot $*
	CMDRESULT=$?
	
	# Unbind /dev from chroot envionment
	umount -l "$CHRDIR/dev"
	
	return $CMDRESULT
}

function load_inside_chroot
{
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
	if [ $# -gt 0 ]; then
		$*
	else
		${SHELL} -i
	fi
	
	CMDRESULT=$?
	CLEANERROR=0
	
	# Remove machine ID
	rm /var/lib/dbus/machine-id || CLEANERROR=1
	
	# Remove diversion
	rm /sbin/initctl && dpkg-divert --rename --remove /sbin/initctl || CLEANERROR=1
	
	# Clean up
	apt-get clean || CLEANERROR=1
	rm -rf /tmp/* || CLEANERROR=1
	rm /etc/resolv.conf || CLEANERROR=1
	mv "$CHRDIR/etc/hosts~" "$CHRDIR/etc/hosts" || CLEANERROR=1
	
	# Umount filesystem
	umount -lf /proc || CLEANERROR=1
	umount -lf /sys || CLEANERROR=1
	umount -lf /dev/pts || CLEANERROR=1
	
	if [ $CMDRESULT -ne 0 ]; then
		return 2
	elif [ $CLEANERROR -ne 0 ]; then
		return 1
	else
		return 0
	fi
}

if [ "$1" == "--inside-chroot" ]; then
	shift
	load_inside_chroot $*
elif [ -n "$1" ]; then
	CHRDIR="$1/chroot"; shift
	load_chroot "$CHRDIR" $*
else
	echo "Usage: $0 <target directory>"
	exit 1
fi

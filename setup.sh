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
if [ ! -d "$1" ]; then
	mkdir -p "$1" || exit 1
fi

WDIR="$(cd "$1" && pwd)" || exit 1
CHRDIR="$WDIR/chroot"

# Install debootstrap
apt-get install --yes debootstrap || exit 1

# Install tools for creating iso
apt-get install --yes syslinux squashfs-tools genisoimage || exit 1

function setup_chroot
{
	# Bootstrap Ubuntu with same arch and release
	RELEASE="$(lsb_release -sc)"
	mkdir -p "$CHRDIR" || return 1
	debootstrap "$RELEASE" "$CHRDIR" || return 1
	
	# Copy apt sources.list configuration
	cp "/etc/apt/sources.list" "$CHRDIR/etc/apt/sources.list" || return 1
}

# Setup chroot
if [ ! -d "$CHRDIR" ]; then
	setup_chroot || ( rm -rf "$CHRDIR" && exit 1 )
fi

# Install mandatory packages
"${CURDIR}/load-chroot.sh" "$WDIR" apt-get install --yes ubuntu-standard casper lupin-casper discover laptop-detect os-prober linux-generic || exit 1

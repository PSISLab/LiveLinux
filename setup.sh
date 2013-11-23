#!/bin/bash

CURDIR="$(cd `dirname $0` && pwd)"

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Install debootstrap
apt-get install --yes debootstrap || exit 1

# Install tools for creating iso
apt-get install --yes netpbm syslinux squashfs-tools genisoimage extlinux || exit 1

# Copy llm script
cp "$CURDIR/llm.sh" "/usr/bin/llm" || exit 1
chmod +x "/usr/bin/llm" || exit 1

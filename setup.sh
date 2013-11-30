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

# Install debootstrap
apt-get install --yes debootstrap || exit 1

# Install tools for creating iso
apt-get install --yes netpbm syslinux squashfs-tools genisoimage extlinux mbr || exit 1

# Copy llm script
cp "$CURDIR/llm.sh" "/usr/bin/llm" || exit 1
chmod +x "/usr/bin/llm" || exit 1

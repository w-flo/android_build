#!/bin/sh
#
# build-emulator-sdcard.sh -- assemble disk-images needed to exeucting emulator
#
# Copyright (C) 2013, Canonical Ltd.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# See file /usr/share/common-licenses/GPL for more details.

set -e
set -x
OUT=out/target/product/generic/
if [ ! -e $OUT/ubuntu-rootfs.tar.xz ]; then
    wget -O $OUT/ubuntu-rootfs.tar.xz `./build/tools/get-tarball-url.py`
fi

sudo umount $OUT/mnt || true

dd if=/dev/zero of=$OUT/ubuntu-system.img bs=1 count=1 seek=3G
mkfs.ext4 -F -L UBUNTU $OUT/ubuntu-system.img

dd if=/dev/zero of=$OUT/sdcard.img bs=1 count=1 seek=4G
mkfs.ext4 -F -L USERDATA $OUT/sdcard.img

mkdir -p $OUT/mnt

sudo mount $OUT/ubuntu-system.img $OUT/mnt
sudo tar --numeric-owner -xf $OUT/ubuntu-rootfs.tar.xz -C $OUT/mnt/

sudo mv $OUT/mnt/system $OUT/mnt/system-unpack
sudo mv $OUT/mnt/system-unpack/* $OUT/mnt/
sudo rmdir $OUT/mnt/system-unpack

## Customizations for the Ubuntu image
sudo sh -c "echo manual > $OUT/mnt/etc/init/bluetooth.override"
# Can't run powerd by default, as suspend & resume breaks the file system
sudo sh -c "echo manual > $OUT/mnt/etc/init/powerd.override"
# SSH can be enabled by default in the emulator
sudo rm $OUT/mnt/etc/init/ssh.override
# XXX: Temporarily disable Unity8 until we're able to make it not to crash
sudo sh -c "echo manual > $OUT/mnt/usr/share/upstart/sessions/unity8.override"

# Default console for qemu
sudo sh -c "cat << EOF > $OUT/mnt/etc/init/ttyS2.conf
# ttyS2 - getty

start on stopped rc RUNLEVEL=[2345] and not-container
stop on runlevel [!2345]

respawn
exec /sbin/getty -8 38400 ttyS2
EOF
"

# Copy the original Android image
sudo cp $OUT/system.img $OUT/mnt/var/lib/lxc/android/system.img

sync
sudo umount $OUT/mnt

sudo mount $OUT/sdcard.img $OUT/mnt
sudo cp $OUT/ubuntu-system.img $OUT/mnt/system.img
sudo touch $OUT/mnt/.writable_image
sync
sudo umount $OUT/mnt

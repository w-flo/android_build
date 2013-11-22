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

dd if=/dev/zero of=$OUT/ubuntu-system.img bs=1 count=0 seek=3G
mkfs.ext4 -F -L UBUNTU $OUT/ubuntu-system.img

dd if=/dev/zero of=$OUT/sdcard.img bs=1 count=0 seek=4G
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
# XXX: Disable NM as it seems to also generate hangs (alone and with ofono)
sudo sh -c "echo manual > $OUT/mnt/etc/init/network-manager.override"
# Setting up the static network config required by QEMU:
# - Using static values as dhclient seems to cause hangs
sudo sh -c "cat << EOF > $OUT/mnt/etc/network/interfaces
# interfaces(5) file used by ifup(8) and ifdown(8)
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 10.0.2.15
    netmask 255.255.255.0
    gateway 10.0.2.2
    dns-nameservers 10.0.2.3
EOF
"
# We don't need voice recognition enabled at hud by default (20s to load)
sudo sh -c "cat << EOF > $OUT/mnt/etc/profile.d/hud-service.sh
export HUD_DISABLE_VOICE=1
EOF
"
# XXX: Disabling core services until the emulator is stable enough
sudo sh -c "echo manual > $OUT/mnt/etc/init/ofono.override"
sudo sh -c "echo manual > $OUT/mnt/etc/init/ubuntu-location-service.override"
sudo sh -c "echo manual > $OUT/mnt/etc/init/whoopsie.override"
sudo sh -c "echo manual > $OUT/mnt/usr/share/upstart/sessions/ofono-setup.override"
sudo sh -c "echo manual > $OUT/mnt/usr/share/upstart/sessions/mediascanner.override"

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

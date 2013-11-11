#!/bin/sh
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

# Customizations for the Ubuntu image
sudo sh -c "echo manual > $OUT/mnt/etc/init/bluetooth.override"

# Copy the original Android image
sudo cp $OUT/system.img $OUT/mnt/var/lib/lxc/android/system.img

sync
sudo umount $OUT/mnt

sudo mount $OUT/sdcard.img $OUT/mnt
sudo cp $OUT/ubuntu-system.img $OUT/mnt/system.img
sudo touch $OUT/mnt/.writable_image
sync
sudo umount $OUT/mnt

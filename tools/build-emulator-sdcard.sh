#!/bin/sh
set -e
set -x
[ -z $OUT ] && exit 1
if [ ! -e $OUT/ubuntu-rootfs.tar.gz ]; then
    wget -O $OUT/ubuntu-rootfs.tar.gz http://cdimage.ubuntu.com/ubuntu-touch/daily-preinstalled/pending/trusty-preinstalled-touch-armhf.tar.gz
fi

dd if=/dev/zero of=$OUT/ubuntu-system.img bs=1 count=1 seek=3G
mkfs.ext4 -F -L UBUNTU $OUT/ubuntu-system.img

dd if=/dev/zero of=$OUT/sdcard.img bs=1 count=1 seek=4G
mkfs.ext4 -F -L USERDATA $OUT/sdcard.img

sudo mount $OUT/ubuntu-system.img /mnt
sudo tar --numeric-owner -xzf $OUT/ubuntu-rootfs.tar.gz -C /mnt/

sudo sh -c "echo manual > /mnt/etc/init/bluetooth.override"

sudo cp $OUT/system.img /mnt/var/lib/lxc/android/system.img

sync
sudo umount /mnt

sudo mount $OUT/sdcard.img /mnt
sudo cp $OUT/ubuntu-system.img /mnt/system.img
sudo touch /mnt/.writable_image
sync
sudo umount /mnt

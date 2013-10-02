#!/bin/sh
set -e
[ -z $OUT ] && exit 1
if [ ! -e $OUT/ubuntu-rootfs.tar.gz ]; then
    wget -O $OUT/ubuntu-rootfs.tar.gz http://cdimage.ubuntu.com/ubuntu-touch/daily-preinstalled/current/saucy-preinstalled-touch-armhf.tar.gz
fi
mksdcard -l USERDATA 3G $OUT/sdcard.img
mkfs.ext4 -F -L USERDATA $OUT/sdcard.img
sudo mount $OUT/sdcard.img /mnt
sudo mkdir -p /mnt/ubuntu
sudo tar --numeric-owner -xzf $OUT/ubuntu-rootfs.tar.gz -C /mnt/ubuntu
sync
sudo umount /mnt

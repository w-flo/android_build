#!/bin/sh
set -e
if [ ! -e ubuntu-rootfs.tar.gz ]; then
    wget -O ubuntu-rootfs.tar.gz http://cdimage.ubuntu.com/ubuntu-touch/daily-preinstalled/current/saucy-preinstalled-touch-armhf.tar.gz
fi
mksdcard -l USERDATA 3G ubuntu-sdcard.img
mkfs.ext4 -F -L USERDATA ubuntu-sdcard.img
sudo mount ubuntu-sdcard.img /mnt
sudo mkdir -p /mnt/ubuntu
sudo tar --numeric-owner -xzf ubuntu-rootfs.tar.gz -C /mnt/ubuntu
sync
sudo umount /mnt

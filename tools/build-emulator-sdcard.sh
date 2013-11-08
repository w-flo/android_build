#!/bin/sh
set -e
set -x
OUT=out/target/product/generic/
if [ ! -e $OUT/ubuntu-rootfs.tar.gz ]; then
    wget -O $OUT/ubuntu-rootfs.tar.gz http://cdimage.ubuntu.com/ubuntu-touch/daily-preinstalled/pending/trusty-preinstalled-touch-armhf.tar.gz
fi

dd if=/dev/zero of=$OUT/ubuntu-system.img bs=1 count=1 seek=3G
mkfs.ext4 -F -L UBUNTU $OUT/ubuntu-system.img

dd if=/dev/zero of=$OUT/sdcard.img bs=1 count=1 seek=4G
mkfs.ext4 -F -L USERDATA $OUT/sdcard.img

mkdir -p $OUT/mnt

sudo mount $OUT/ubuntu-system.img $OUT/mnt
sudo tar --numeric-owner -xzf $OUT/ubuntu-rootfs.tar.gz -C $OUT/mnt/

# Customizations for the Ubuntu image
sudo sh -c "echo manual > $OUT/mnt/etc/init/bluetooth.override"

# Set up all the directories and links (simulate ro image setup)
sudo mkdir -p $OUT/mnt/userdata $OUT/mnt/lib/modules
for dir in cache data factory firmware persist system; do
    sudo ln -s /android/$dir $OUT/mnt/$dir
done
sudo ln -s /android/system/vendor $OUT/mnt/vendor

# Copy the original Android image
sudo cp $OUT/system.img $OUT/mnt/var/lib/lxc/android/system.img

sync
sudo umount $OUT/mnt

sudo mount $OUT/sdcard.img $OUT/mnt
sudo cp $OUT/ubuntu-system.img $OUT/mnt/system.img
sudo touch $OUT/mnt/.writable_image
sync
sudo umount $OUT/mnt

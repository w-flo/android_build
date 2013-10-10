#!/bin/sh
set -e
set -x
[ -z $OUT ] && exit 1
if [ ! -e $OUT/ubuntu-rootfs.tar.gz ]; then
    wget -O $OUT/ubuntu-rootfs.tar.gz http://cdimage.ubuntu.com/ubuntu-touch/daily-preinstalled/current/saucy-preinstalled-touch-armhf.tar.gz
fi
mksdcard -l UBUNTU 3G $OUT/ubuntu-system.img
mkfs.ext4 -F -L UBUNTU $OUT/ubuntu-system.img

mksdcard -l USERDATA 4G $OUT/sdcard.img
mkfs.ext4 -F -L USERDATA $OUT/sdcard.img

sudo mount $OUT/ubuntu-system.img /mnt
sudo tar --numeric-owner -xzf $OUT/ubuntu-rootfs.tar.gz -C /mnt/

sudo sh -c "cat > /mnt/etc/init/ttyS2.conf" <<EOF
start on startup
stop on runlevel [!12345]

respawn
exec /sbin/getty -L 115200 ttyS2 vt102
EOF

sudo sh -c "cat > /mnt/usr/lib/lxc-android-config/70-generic.rules" <<EOF
ACTION=="add", KERNEL=="qemu_trace", OWNER="system", GROUP="system", MODE="0666"
ACTION=="add", KERNEL=="qemu_pipe", OWNER="system", GROUP="system", MODE="0666"
ACTION=="add", KERNEL=="ttyS*", OWNER="system", GROUP="system", MODE="0666"
EOF

sudo cp $OUT/system.img /mnt/var/lib/lxc/android/system.img

sync
sudo umount /mnt

sudo mount $OUT/sdcard.img /mnt
sudo cp $OUT/ubuntu-system.img /mnt/system.img
sudo touch /mnt/.writable_image
sync
sudo umount /mnt

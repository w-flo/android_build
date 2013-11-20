#!/bin/sh
#
# run-emulator.sh -- execute emulator with correct args
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

export PATH=out/host/linux-x86/bin/:$PATH

if [ ! -e out/target/product/generic/sdcard.img ]
then
    echo "No sdcard.img, run build-emulator-sdcard.sh first!"
    exit 1
fi

emulator -memory 512 -skin WVGA800 -skindir development/tools/emulator/skins -sysdir out/target/product/generic \
    -system out/target/product/generic/system.img -data out/target/product/generic/userdata.img -cache out/target/product/generic/cache.img \
    -sdcard out/target/product/generic/sdcard.img -kernel out/target/product/generic/ubuntu/kernel/vmlinuz -force-32bit \
    -shell -no-jni -show-kernel -verbose -no-snapstorage -gpu on -qemu -cpu cortex-a9 -append 'apparmor=0'

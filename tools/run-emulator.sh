#!/bin/sh
export PATH=out/host/linux-x86/bin/:$PATH

if [ ! -e out/target/product/generic/sdcard.img ]
then
    echo "No sdcard.img, run build-emulator-sdcard.sh first!"
    exit 1
fi

emulator -memory 512 -sysdir out/target/product/generic/ -system out/target/product/generic/system.img -data out/target/product/generic/userdata.img -cache out/target/product/generic/cache.img -sdcard out/target/product/generic/sdcard.img -kernel out/target/product/generic/ubuntu/kernel/vmlinuz -shell -no-jni -show-kernel -verbose -no-snapstorage -qemu -cpu cortex-a8

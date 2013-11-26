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

set -e

export PATH="out/host/linux-x86/bin/:$PATH"

sysdir="out/target/product/generic"
disk_system="$sysdir/system.img"
disk_userdata="$sysdir/userdata.img"
disk_cache="$sysdir/cache.img"
disk_sdcard="$sysdir/sdcard.img"
disks="$disk_system $disk_userdata $disk_cache $disk_sdcard"

snapshot="pristine"

#
# Subroutines
#
usage() {
    script=`basename $0`
    cat <<EOM

Usage: $script
       $script [COMMAND]

Commands:
 use-disk-snapshots     Convert images to qcow2 and create '$snapshot' snapshot
 convert-disk DISK      Convert DISK to qcow2 and create '$snapshot' snapshot
 snapshot-disks         Update '$snapshot' snapshot to current state
 revert-disks           Revert current images to '$snapshot' snapshot
 info-disks             Show disk information for current images

Without arguments, run the emulated image.

Note: these commands only manipulate the qemu qcow2 disk images and are
      unrelated to the -snapshot* and -no-snapshot* emulator command line
      options
EOM
}

convert_disk() {
    disk="$1"
    if [ -z "$disk" ] || [ ! -e "$disk" ]; then
        echo "Could not find '$disk'" >&2
        exit 1
    fi

    if ! qemu-img info "$disk" | grep -q 'file format: raw' ; then
        echo "'$disk' is not a raw image" >&2
        exit 1
    fi
    echo "Converting $disk ..."
    qemu-img convert -f raw "$disk" -O qcow2 -o compat=0.10 "${disk}.qcow2"
    qemu-img check "${disk}.qcow2"
    mv -f "${disk}.qcow2" "$disk"
    qemu-img snapshot -c "$snapshot" "$disk"
    qemu-img snapshot -l "$disk"
}

use_snapshots_for_disks() {
    error=
    for disk in $disks ; do
        if ! qemu-img info "$disk" | grep -q 'file format: raw' ; then
            error="yes"
            echo "'$disk' is not a raw image" >&2
        fi
    done
    if [ "$error" = "yes" ]; then
        exit 1
    fi

    for disk in $disks ; do
        convert_disk "$disk"
    done
    echo ""
    echo "Successfully converted all images to qcow2 with a '$snapshot' snapshot"
}

revert_disks() {
    error=
    for disk in $disks ; do
        if ! qemu-img info "$disk" | grep -q 'file format: qcow2' ; then
            error="yes"
            echo "'$disk' is not a qcow2 image" >&2
        fi
    done
    if [ "$error" = "yes" ]; then
        exit 1
    fi
    for disk in $disks ; do
        echo "Reverting $disk ..."
        qemu-img snapshot -a "$snapshot" "$disk"
        qemu-img check "$disk"
        qemu-img snapshot -l "$disk"
    done
    echo ""
    echo "Successfully reverted all images to '$snapshot'"
}

snapshot_disks() {
    error=
    for disk in $disks ; do
        if ! qemu-img info "$disk" | grep -q 'file format: qcow2' ; then
            error="yes"
            echo "'$disk' is not a qcow2 image" >&2
        fi
    done
    if [ "$error" = "yes" ]; then
        exit 1
    fi
    # qemu-img snapshot allows creating a snapshot with the same name (it gets
    # a different ID though). When you delete a snapshot by name, the oldest
    # snapshot is deleted.
    for disk in $disks ; do
        echo "Updating '$snapshot' snapshot for $disk ..."
        qemu-img snapshot -c "$snapshot" "$disk" # create new pristine snapshot
        qemu-img snapshot -d "$snapshot" "$disk" # delete oldest pristine snapshot
        qemu-img check "$disk"
        qemu-img snapshot -l "$disk"
    done
    echo ""
    echo "Successfully updated '$snapshot' for all images"
}

info_disks() {
    for disk in $disks ; do
        echo "$ qemu-img info $disk"
        qemu-img info "$disk"
        echo ""
    done
}

#
# Main
#
if [ ! -e "$disk_sdcard" ]; then
    echo "No sdcard.img, run build-emulator-sdcard.sh first!" >&2
    exit 1
fi

if ! which qemu-img >/dev/null ; then
    echo "Please install qemu-utils" >&2
    exit 1
fi

if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "help" ]; then
    usage
    exit
elif [ "$1" = "convert-disk" ]; then
    if [ -z "$2" ]; then
        usage
        exit 1
    fi
    convert_disk "$2"
    exit
elif [ "$1" = "use-disk-snapshots" ]; then
    use_snapshots_for_disks
    exit
elif [ "$1" = "snapshot-disks" ]; then
    snapshot_disks
    exit
elif [ "$1" = "revert-disks" ]; then
    revert_disks
    exit
elif [ "$1" = "info-disks" ]; then
    info_disks
    exit
elif [ -n "$1" ]; then
    usage
    exit 1
fi

# Note: -no-snapstorage disables all qemu snapshotting functionality, which is
# different than the 'qemu-img snapshot' disk commands, above
exec emulator -memory 512 \
    -skin WVGA800 -skindir development/tools/emulator/skins \
    -sysdir "$sysdir" \
    -system "$disk_system" \
    -data "$disk_userdata" \
    -cache "$disk_cache" \
    -sdcard "$disk_sdcard" \
    -kernel "$sysdir/ubuntu/kernel/vmlinuz" \
    -force-32bit \
    -shell -no-jni -show-kernel -verbose \
    -no-snapstorage \
    -gpu on -qemu -cpu cortex-a9 \
    -append 'apparmor=0'


#!/usr/bin/env bash

set -e

input_file=$1

get_uint32()
{
    echo $((0x$(od -N4 -An -j$1 -t x4 | awk '{ print $1 }')))
}

page_align()
{
    if [ "$(($2 % $1))" -eq 0 ]; then
        echo $2
        exit 0
    fi

    echo $((($2 + $1) & ~($1 - 1)))
}

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <bootimg>"
    echo "  Patch <bootimg> to bypass signature verification for Xiaomi Redmi 5A"
    echo "  See: https://xdaforums.com/t/bypass-bootloader-lock-of-redmi-5a-riva-without-permission-from-xiaomi.3772381"
    exit 1
fi

if [ "$(head -c 8 < $input_file)" != "ANDROID!" ]; then
    echo "Refusing to patch an unknown file."
    exit 1
fi

kernel_sz=$(get_uint32 8 < $input_file)
ramdisk_sz=$(get_uint32 16 < $input_file)
second_sz=$(get_uint32 24 < $input_file)
page_sz=$(get_uint32 36 < $input_file)
dtb_sz=$(get_uint32 40 < $input_file)

kernel_actual=$(page_align $page_sz $kernel_sz)
ramdisk_actual=$(page_align $page_sz $ramdisk_sz)
second_actual=$(page_align $page_sz $second_sz)
dtb_actual=$(page_align $page_sz $dtb_sz)

bootimg_actual=$(($page_sz + $kernel_actual + $ramdisk_actual + $second_actual + $dtb_actual))

echo -e "Page_size\t\t: $page_sz"

echo -e "Kernel size\t\t: $kernel_sz (actual $kernel_actual)"
echo -e "Ramdisk size\t\t: $ramdisk_sz (actual $ramdisk_actual)"
echo -e "Second-stage BL size\t: $second_sz (actual $second_actual)"
echo -e "DTB size\t\t: $dtb_sz (actual $dtb_actual)"

echo -e "Bootimg actual size\t: $bootimg_actual"

echo
echo "Patching $input_file at $bootimg_actual"

printf '\x30\x83\x19\x89\x64' | dd of="$1" seek=$bootimg_actual ibs=$page_sz obs=1 conv=sync,notrunc 2> /dev/null

#!/bin/sh

[ ! -e "$1" ] && echo "usage: $0 /dev/partition" && exit 1

mkdir bitlocker mnt
dislocker -V "$1" -K vmk.dat -vvv -- bitlocker
mount -t ntfs-3g -o loop bitlocker/dislocker-file mnt

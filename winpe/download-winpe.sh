#!/bin/sh
set -e

__() { printf "\n\033[1;32m* %s [%s]\033[0m\n" "$1" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"; }

__ "Installing required tools"

apk add bash curl uuidgen qemu-img jq wimlib 7zip

__ "Fetching Quickemu"

wget "https://github.com/quickemu-project/quickemu/archive/refs/tags/4.9.7.tar.gz" -O quickemu.tar.gz \
    && echo '38a93301a2b233bc458c62d1228d310a9c29c63c10d008c2905029ca66188606  quickemu.tar.gz' \
    | sha256sum -c || exit 1

tar xzf quickemu.tar.gz

__ "Fetching Windows 11"

./quickemu-*/quickget --download windows 11

__ "Extracting artifacts from Windows ISO"

7z e Win11_24H2_EnglishInternational_x64.iso sources/boot.wim boot/boot.sdi

wiminfo boot.wim 1 --boot
wiminfo boot.wim

__ "Copying artifacts to TFTP directory"

cp boot.wim /mnt/tftp/Boot
cp boot.sdi /mnt/tftp/Boot

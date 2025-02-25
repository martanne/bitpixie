#!/bin/sh
set -e

__() { printf "\n\033[1;32m* %s [%s]\033[0m\n" "$1" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"; }

__ "Installing required tools"

apk add make mingw-w64-gcc

__ "Building search-vmk"

cd /src
make windows

__ "Copying artifacts to SMB directory"

cp search-vmk.exe /mnt/smb/winpe

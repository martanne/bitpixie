#!/bin/sh
set -e

__() { printf "\n\033[1;32m* %s [%s]\033[0m\n" "$1" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"; }

__ "Installing required tools"

apk add make cmake mingw-w64-gcc

__ "Getting WinPmem source"

wget "https://github.com/martanne/WinPmem-BitLocker/archive/1e8ad783862e76b72aa17c0e0937bed6776cb442.tar.gz" -O winpmem.tar.gz \
    && echo '30279694816d75f4af2e51932b85512723945ccadd2e2e58fffecbc42f1b77a3  winpmem.tar.gz' \
    | sha256sum -c || exit 1

tar xf winpmem.tar.gz && cd WinPmem-*

__ "Building WinPmem"

cd src/executable
iconv -f UTF-16LE -t UTF-8 winpmem.rc > winpmem.utf8.rc
sed -i 's,\\\\,/,g' winpmem.utf8.rc
x86_64-w64-mingw32-windres winpmem.utf8.rc -O coff -o resources.o
x86_64-w64-mingw32-g++ -DUNICODE -D_UNICODE -municode -mconsole -static main.cpp winpmem.cpp resources.o -o winpmem 

__ "Copying artifacts to SMB directory"

cp winpmem.exe /mnt/smb/winpe

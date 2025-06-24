#!/bin/sh
set -e

__() { printf "\n\033[1;32m* %s [%s]\033[0m\n" "$1" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"; }

__ "Installing required tools"

apk add make cmake mingw-w64-gcc

__ "Getting Mbed TLS source"


wget "https://github.com/Mbed-TLS/mbedtls/archive/refs/tags/mbedtls-3.6.2.tar.gz" -O mbedtls.tar.gz \
    && echo 'a3c959773bc5d5b22353bc605e96d92fae2eac486dcaf46990412b84a1a0fb5f  mbedtls.tar.gz' \
    | sha256sum -c || exit 1

export DESTDIR=$(pwd)/build
mkdir -p ${DESTDIR}
tar xf mbedtls.tar.gz && cd mbedtls-*

__ "Building Mbed TLS"

make CC=x86_64-w64-mingw32-gcc AR=x86_64-w64-mingw32-ar WINDOWS_BUILD=1 lib

mkdir -p ${DESTDIR}/include/mbedtls
cp -rp include/mbedtls ${DESTDIR}/include
mkdir -p ${DESTDIR}/include/psa
cp -rp include/psa ${DESTDIR}/include

mkdir -p ${DESTDIR}/lib
cp -RP library/libmbedtls.*    ${DESTDIR}/lib
cp -RP library/libmbedx509.*   ${DESTDIR}/lib
cp -RP library/libmbedcrypto.* ${DESTDIR}/lib

cd -

__ "Crating CMake toolchain file"

cat <<'EOF' > mingw-w64-x86_64.cmake
# Sample toolchain file for building for Windows from an Ubuntu Linux system.
#
# Typical usage:
#    *) install cross compiler: `sudo apt-get install mingw-w64`
#    *) cd build
#    *) cmake -DCMAKE_TOOLCHAIN_FILE=~/mingw-w64-x86_64.cmake ..
# This is free and unencumbered software released into the public domain.

set(CMAKE_SYSTEM_NAME Windows)
set(TOOLCHAIN_PREFIX x86_64-w64-mingw32)

# cross compilers to use for C, C++ and Fortran
set(CMAKE_C_COMPILER ${TOOLCHAIN_PREFIX}-gcc)
set(CMAKE_CXX_COMPILER ${TOOLCHAIN_PREFIX}-g++)
set(CMAKE_Fortran_COMPILER ${TOOLCHAIN_PREFIX}-gfortran)
set(CMAKE_RC_COMPILER ${TOOLCHAIN_PREFIX}-windres)

# target environment on the build host system
set(CMAKE_FIND_ROOT_PATH /usr/${TOOLCHAIN_PREFIX} MBED_TLS_DIR)

# modify default behavior of FIND_XXX() commands
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF

sed -i "s,MBED_TLS_DIR,$DESTDIR,g" mingw-w64-x86_64.cmake

__ "Getting dislocker source"


wget https://github.com/martanne/dislocker-metadata-win32/archive/dbb4545a368fc695e3020b149bd0f381234afe0b.tar.gz -O "dislocker.tar.gz" \
    && echo "a55377715ee988df9ef3c60a92eaa704cd2c098b74f1d8c6494fcb098b634be6  dislocker.tar.gz" \
    | sha256sum -c || exit 1

tar xf dislocker.tar.gz

__ "Building dislocker"


cd dislocker-*

cmake -DCMAKE_TOOLCHAIN_FILE=../mingw-w64-x86_64.cmake -DCMAKE_INSTALL_PREFIX=/tmp/dislocker -DWITH_FUSE=OFF -DWITH_RUBY=OFF

x86_64-w64-mingw32-gcc -I./include -I${DESTDIR}/include -DPROGNAME=\"dislocker-metadata\" \
	-DAUTHOR=\"Romain\ Coltel\" -DVERSION=\"0.7.2-unsupported\" -D__OS=\"Windows\" \
	-D__ARCH=\"x86_64\" -D_FILE_OFFSET_BITS=64 src/dislocker-metadata.c src/metadata/*.c src/common.c \
	src/ntfs/clock.c src/ntfs/encoding.c src/encryption/crc32.c src/encryption/aes-xts.c \
	src/encryption/decrypt.c src/encryption/diffuser.c src/xstd/xstdio.c src/xstd/xstdlib.c \
	-L${DESTDIR}/lib -lmbedtls -lmbedcrypto -lmbedx509 -o dislocker-metadata

__ "Copying artifacts to SMB directory"

cp dislocker-metadata.exe /mnt/smb/winpe

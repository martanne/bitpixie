#!/bin/sh

scriptpath="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

sudo docker run --platform linux/amd64 --rm \
    -p 445:445/tcp \
    -v "$scriptpath/smb":/data \
    4poki4/impacket \
    smbserver.py -smb2support smb /data

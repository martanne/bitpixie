#!/bin/sh

scriptpath="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

sudo $(which smbserver.py) -smb2support smb "$scriptpath/smb"

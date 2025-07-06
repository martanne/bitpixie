#!/bin/sh

[ $# -eq 0 ] && echo "usage: $0 <interface>" && exit 1

scriptpath="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
interface=$1

sudo ip a add 10.13.37.100/24 dev $interface

# We need host network because dnsmasq checks if it binds to an address in 10.13.37.0/24
sudo docker run --cap-add=NET_ADMIN \
    --volume="$scriptpath/tftp":/data \
    --volume="$scriptpath/smb/BCD":/data/Boot/BCD \
    --network host \
    4km3/dnsmasq --no-daemon \
    --log-facility=- \
	--interface=$interface \
	--dhcp-range=10.13.37.100,10.13.37.200,255.255.255.0,1h \
	--dhcp-boot=bootmgfw.efi \
	--enable-tftp \
	--tftp-root=/data \
	--log-dhcp



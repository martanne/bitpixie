#!/bin/sh
set -e

rc-update add devfs sysinit
rc-update add dmesg sysinit
rc-update add udev sysinit
rc-update add udev-trigger sysinit
rc-update add udev-settle sysinit

rc-update add udev-postmount default

rc-update add hwclock boot
rc-update add modules boot
rc-update add sysctl boot
rc-update add hostname boot
rc-update add bootmisc boot
rc-update add syslog boot
rc-update add klogd boot
rc-update add networking boot

rc-update add mount-ro shutdown
rc-update add killprocs shutdown

ln -s /etc/init.d/agetty /etc/init.d/agetty.ttyS0
rc-update add agetty.ttyS0 default

This prepares a PXE boot environment to exploit the bitpixie vulnerability.

The kernel (`linux`) and initramfs (`alpine-initrd.xz`) is expected to be provided externally,
e.g. by running the scripts in the (corresponding linux directory](../linux).

The `download.sh` script fetches the required components from public sources:
 - `shimx64.efi` signed Debian shim
 - `grubx64.efi` signed Debian GRUB boot loader
 - TODO: `bootmgfw.efi` vulnerable Windows boot manager

The `start-smb.sh` script starts an impacket based SMB server providing the 
[`create-bcd.bat`](./smb/create-bcd.bat) script to generate a device specific
BCD.

The `start-pxe.sh` script starts `dnsmasq` with the needed options to serve
the file from the [tftp](./tftp/) directory.

```
$ ./download.sh
$ ./start-smb.sh
$ ./start-pxe.sh eth0
```

This work was done in parallel and drew some inspiration from similar avenues by [Andreas Grasser](https://github.com/andigandhi/bitpixie/).

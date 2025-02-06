This prepares a PXE boot environment to exploit the bitpixie vulnerability.

The kernel (`linux`) and initramfs (`alpine-initrd.xz`) is expected to be provided externally,
e.g. by running the scripts in the [corresponding linux directory](../linux).

The `download.sh` script fetches some of the required components from public sources:
 - `shimx64.efi` signed Debian shim
 - `grubx64.efi` signed Debian GRUB boot loader

Unfortunately, the vulnerable Windows boot manager `bootmgfw.efi` is not available
as a convenient standalone download. Its SHA256 hash can be looked up in
[Winbindex](https://winbindex.m417z.com/?file=bootmgfw.efi) to get the following
metadata:

 - Update: KB5019311 (OS Build 22621.525) released on 2022-09-27
 - File version: 10.0.22621.457
 - Signing date: 2022-08-11

```
$ sha256sum bootmgfw.efi
b5632b54120f887ec3d1f1f405ad75c71a2c066ddb34e54efa374c4f7190b2c1  bootmgfw.efi
```

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

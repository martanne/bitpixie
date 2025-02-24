This is an Alpine Linux based initramfs intended to exploit the bitpixie vulnerability.

It is based on a Filippo Valsorda's rootfs-free immutable NAS project.
See [frood, an Alpine initramfs NAS](https://words.filippo.io/dispatches/frood/).
To avoid confusion the script has been renamed to `bitpixie`.

You need to have Docker installed.

```
$ ./bitpixie build
$ ./bitpixie qemu     # optional sanity check
$ ./bitpixie deploy
```

In case you want to adapt it to your needs:

 - `packages` contains a list of alpine packages to install
 - `root` contains files and directories which will be copied to the initramfs
 - `setup.sh` is a shell script which is run during "installation" i.e. when `alpine-make-rootfs(1)` is executed
 - `bitpixie-build.sh` runs in an Alpine container and copies the necessary bitpixie related files into the initialramfs

This is not maintained for others to use, but you are welcome to copy it and
modify it under the terms of [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).
Feel free to share your modifications, or not.

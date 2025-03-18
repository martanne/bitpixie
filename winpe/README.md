This directory contains build and helper scripts for WinPE based attack strategies.

The shell scripts are executed within an Alpine Linux container started
from the top-level Makefile when invoking `make winpe`:

 - `download-winpe.sh` downloads a Windows 11 ISO and extracts the WinPE image and ramdisk
 - `build-search-vmk.sh` builds the generic [`search-vmk` utility](../search-vmk/) for Windows
 - `build-dislocker-metadata.sh` builds the minimal Windows port of
   [disklocker-metadata](https://github.com/martanne/dislocker-metadata-win32) to recover the
   human readable BitLocker recovery password given the VMK

The [`Customize-WinPE.ps1` PowerShell] script is intended to create a customized
WinPE environment with BitLocker support by automating the steps outlined in the
[official Microsoft documentation](https://learn.microsoft.com/en-us/windows/deployment/customize-boot-image).

It requires that the [Windows ADK](https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install)
(`adksetup.exe`) as well as the [Windows PE add-on for the Windows ADK](https://go.microsoft.com/fwlink/?linkid=2289981)
(`adkwinpesetup.exe`) have already been installed.

Assuming default installation location of these, a customized WinPE environment
with all required components for BitLocker support can be built with:

```
PS C:\> Customize-WinPE -WinPEMountPoint "C:\winpe-bitlocker"
```

The above procedure updated the default `winpe.wim` image from the ADK, based on
which the necessary files can be extracted:

 1. Start elevated instance of *Deployment and Imaging Tools Environment*
 2. Create WinPE environment `copype amd64 c:\winpe-bitpixie`
 3. Copy the required files to the `Boot` directory of your TFTP server:
     - `C:\winpe-bitpixie\media\boot\boot.sdi`
     - `C:\winpe-bitpixie\media\sources\boot.wim

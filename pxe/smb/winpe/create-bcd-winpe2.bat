REM @echo off

bcdedit /export BCD_winpe2

bcdedit /store BCD_winpe2 /create {ramdiskoptions} /d "Ramdisk options"
bcdedit /store BCD_winpe2 /set {ramdiskoptions} ramdisksdidevice boot
bcdedit /store BCD_winpe2 /set {ramdiskoptions} ramdisksdipath \Boot\boot.sdi

bcdedit /store BCD_winpe2 /create /d "winpe boot image" /application osloader > GUID.txt

for /F "tokens=2 delims={}" %%i in (GUID.txt) do (set REBOOT_GUID=%%i)
del GUID.txt

bcdedit /store BCD_winpe2 /set {%REBOOT_GUID%} device ramdisk=[boot]\Boot\boot.wim,{ramdiskoptions}

bcdedit /store BCD_winpe2 /set {%REBOOT_GUID%} path \Windows\System32\winload.efi
bcdedit /store BCD_winpe2 /set {%REBOOT_GUID%} osdevice ramdisk=[boot]\Boot\boot.wim,{ramdiskoptions}
bcdedit /store BCD_winpe2 /set {%REBOOT_GUID%} systemroot \Windows
bcdedit /store BCD_winpe2 /set {%REBOOT_GUID%} detecthal yes
bcdedit /store BCD_winpe2 /set {%REBOOT_GUID%} winpe yes

bcdedit /store BCD_winpe2 /displayorder {%REBOOT_GUID%} /addlast
bcdedit /store BCD_winpe2 /default {%REBOOT_GUID%}
bcdedit /store BCD_winpe2 /set {bootmgr} timeout 0

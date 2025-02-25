REM @echo off

bcdedit /export BCD_winpe1

bcdedit /store BCD_winpe1 /create /d "softreboot" /application startup > GUID.txt

for /F "tokens=2 delims={}" %%i in (GUID.txt) do (set REBOOT_GUID=%%i)
del GUID.txt

bcdedit /store BCD_winpe1 /set {%REBOOT_GUID%} path "\bootmgfw-stage2.efi"
bcdedit /store BCD_winpe1 /set {%REBOOT_GUID%} device boot
bcdedit /store BCD_winpe1 /set {%REBOOT_GUID%} pxesoftreboot yes

bcdedit /store BCD_winpe1 /set {default} recoveryenabled yes
bcdedit /store BCD_winpe1 /set {default} recoverysequence {%REBOOT_GUID%}
bcdedit /store BCD_winpe1 /set {default} path "\\"
bcdedit /store BCD_winpe1 /set {default} winpe yes

bcdedit /store BCD_winpe1 /displayorder {%REBOOT_GUID%} /addlast

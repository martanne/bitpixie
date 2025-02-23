REM @echo off

bcdedit /export BCD_linux

bcdedit /store BCD_linux /create /d "softreboot" /application startup > GUID.txt
for /F "tokens=2 delims={}" %%i in (GUID.txt) do (set REBOOT_GUID=%%i)
del GUID.txt

bcdedit /store BCD_linux /set {%REBOOT_GUID%} path "\shimx64.efi"
bcdedit /store BCD_linux /set {%REBOOT_GUID%} device boot
bcdedit /store BCD_linux /set {%REBOOT_GUID%} pxesoftreboot yes

bcdedit /store BCD_linux /set {default} recoveryenabled yes
bcdedit /store BCD_linux /set {default} recoverysequence {%REBOOT_GUID%}
bcdedit /store BCD_linux /set {default} path "\\"
bcdedit /store BCD_linux /set {default} winpe yes

bcdedit /store BCD_linux /displayorder {%REBOOT_GUID%} /addlast

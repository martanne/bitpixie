#!/bin/sh

[ $# -eq 0 ] && echo "usage: $0 <interface>" && exit 1

scriptpath="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
interface=$1

sudo ip a add 10.13.37.100/24 dev $interface

cat <<'EOF' > "$scriptpath/dnsmasq.winpe.gdb"
set breakpoint pending on
break open
break open
condition 1 $_regex(file, ".*/bootmgfw\\.efi$")
commands 1
  print "Preparing stage 1"
  disable 1
  enable 2
  shell ln -sf BCD_winpe1 smb/BCD
  continue
end
condition 2 $_regex(file, ".*/bootmgfw-stage2\\.efi$")
commands 2
  print "Preparing stage 2"
  disable 2
  # would restore initial state, but might interfere, restart script instead
  #enable 1
  shell ln -sf BCD_winpe2 smb/BCD
  continue
end
catch load
commands
  enable 1
  disable 2
  continue
end
run
EOF

sudo gdb -x dnsmasq.winpe.gdb --args dnsmasq --no-daemon \
	--interface=$interface \
	--dhcp-range=10.13.37.100,10.13.37.200,255.255.255.0,1h \
	--dhcp-boot=bootmgfw.efi \
	--enable-tftp \
	--tftp-root="$scriptpath/tftp" \
	--log-dhcp

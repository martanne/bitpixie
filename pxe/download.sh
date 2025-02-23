#!/bin/sh

if [ -f tftp/grubx64.efi ] && [ -f tftp/shimx64.efi ]; then
	echo "Skipping Linux related artifacts download"
else
	docker run --platform linux/amd64 --rm -v "$PWD":/mnt -w /root \
		alpine:3.20.3 "/mnt/download-linux.sh"
fi

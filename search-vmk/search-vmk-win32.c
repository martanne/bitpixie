#include <windows.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>

#define VMK_HDR "-FVE-FS-"
#define VMK_HDR_SIZE (sizeof(VMK_HDR) - 1)

static void hexDump(const char* description, const void* data, size_t size, size_t block) {
	const uint8_t* byteData = (const uint8_t*)data;
	size_t i, j;

	if (description)
		printf("%s:\n", description);

	for (i = 0; i < size; i += block) {
		printf(" %04zx  ", i);

		for (j = 0; j < block; j++) {
			if (i + j < size)
				printf("%02x ", byteData[i + j]);
			else
				printf("   ");
		}

		printf("  ");
		for (j = 0; j < block; j++) {
			if (i + j < size) {
				uint8_t c = byteData[i + j];
				printf("%c", (c >= 32 && c <= 126) ? c : '.');
			} else {
				printf(" ");
			}
		}
		printf("\n");
	}
}

void* memmem(const void* haystack, size_t haystack_len, const void* needle, size_t needle_len) {
	if (!haystack || !needle || haystack_len < needle_len)
		return NULL;

	const uint8_t* h = (const uint8_t*)haystack;
	const uint8_t* n = (const uint8_t*)needle;

	for (size_t i = 0; i <= haystack_len - needle_len; i++) {
		if (memcmp(h + i, n, needle_len) == 0)
			return (void*)(h + i);
	}
	return NULL;
}

int main(int argc, char* argv[]) {
	if (argc < 2) {
		fprintf(stderr, "Usage: %s <memory-dump> [vmk-file]\n", argv[0]);
		return EXIT_FAILURE;
	}

	const char* filename = argv[1];
	HANDLE hFile = CreateFileA(filename, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
	if (hFile == INVALID_HANDLE_VALUE) {
		fprintf(stderr, "Failed to open file: %lu\n", GetLastError());
		return EXIT_FAILURE;
	}

	LARGE_INTEGER fileSize;
	if (!GetFileSizeEx(hFile, &fileSize)) {
		fprintf(stderr, "Failed to get file size: %lu\n", GetLastError());
		return EXIT_FAILURE;
	}

	HANDLE hMapping = CreateFileMapping(hFile, NULL, PAGE_READONLY, fileSize.HighPart, fileSize.LowPart, NULL);
	if (!hMapping) {
		fprintf(stderr, "Failed to create file mapping: %lu\n", GetLastError());
		return EXIT_FAILURE;
	}

	void* file_map = MapViewOfFile(hMapping, FILE_MAP_READ, 0, 0, fileSize.QuadPart);
	if (!file_map) {
		fprintf(stderr, "Failed to map view of file: %lu\n", GetLastError());
		return EXIT_FAILURE;
	}

	CloseHandle(hMapping);
	CloseHandle(hFile);

	size_t size = fileSize.QuadPart;
	void *search_start = file_map;
	void *search_end = search_start + size;

	while (search_start < search_end) {

		void* pmd_vmk_hdr_addr = memmem(search_start, size, VMK_HDR, VMK_HDR_SIZE);
		if (pmd_vmk_hdr_addr == NULL)
			break;

		size_t offset = pmd_vmk_hdr_addr - search_start + VMK_HDR_SIZE;
		search_start += offset;
		size -= offset;

		size_t global_offset = pmd_vmk_hdr_addr - file_map;

		// We have found a potential VMK! hexdump the area around it!
		printf("[+] found possible VMK base: %p -> %016llx\n", pmd_vmk_hdr_addr, global_offset);
		hexDump("VMK Candidate", pmd_vmk_hdr_addr, 0x10*20, 0x10);


		uint32_t version = *(uint32_t*)(pmd_vmk_hdr_addr + 8+4);
		uint32_t start = *(uint32_t*)(pmd_vmk_hdr_addr + 8+4+4);
		uint32_t end = *(uint32_t*)(pmd_vmk_hdr_addr + 8+4+4+4);
		if (version != 1) {
			printf("[+] VERSION MISMATCH! %d\n", version);
			continue;
		} else {
			printf("[+] VERSION MATCH! %d\n", version);
		}

		if (end <= start) {
			printf("[+] NOT ENOUGH SIZE! %x, %x\n", start, end);
			continue;
		}

		// Now we found the correct VMK struct, look for more bytes that signal start of VMK
		// No idea what they actually represent, just bindiffed win10/11 struct in memory and found them to be constant here.
		void* pmd_vmk_addr = memmem(pmd_vmk_hdr_addr, end, "\x03\x20\x01\x00", 4);
		if (pmd_vmk_addr == NULL) {
			printf("[+] VMK-needle not found!\n");
			continue;
		} else {
			printf("[+] found VMK-needle at: %p\n", pmd_vmk_addr);
		}

		char* vmk = pmd_vmk_addr + 4;
		printf("[+] found VMK at: %p \n", vmk);
		hexDump("VMK", vmk, 0x10*2, 0x10);

		if (argc > 2) {
			const char *output = argv[2];
			FILE *file = fopen(output, "wb");
			if (!file) {
				printf("[-] failed to open output file: %s\n", output);
				return EXIT_SUCCESS;
			}
			fwrite(vmk, sizeof(char), 32, file);
			fclose(file);
			printf("[+] wrote VMK to file: %s\n", output);
		}
		return EXIT_SUCCESS;
	}

	printf("[-] did not find VMK header\n");
	return EXIT_FAILURE;
}

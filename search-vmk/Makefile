all: posix windows

posix: search-vmk

windows: search-vmk.exe

search-vmk: search-vmk-posix.c
	cc -Wall -Wextra search-vmk-posix.c -o $@

search-vmk.exe: search-vmk-win32.c
	x86_64-w64-mingw32-gcc -Wall -Wextra search-vmk-win32.c -o $@

clean:
	rm -f search-vmk search-vmk.exe

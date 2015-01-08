all:
	cd ext\rtmpdump && $(MAKE) -f Makefile.msvc.mak
	copy ext\rtmpdump\build\msvs\Release\rtmpdump.exe ext\rtmpdump\rtmpdump.exe

clean:
	cd ext\rtmpdump && msbuild build\msvs\rtmpdump.vcxproj /target:Clean /p:Configuration=Release
	cd ext\rtmpdump\ext\openssl && $(MAKE) -f ms\nt.mak vclean

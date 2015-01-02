all:
	cd ext/rtmpdump && make SYS=$(SYS)
	cd ext/rtmpdump && install_name_tool -change /usr/local/lib/librtmp.0.dylib @executable_path/librtmp/librtmp.0.dylib rtmpdump

clean:
	cd ext/rtmpdump && make clean

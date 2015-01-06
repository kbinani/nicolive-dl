all:
	cd ext/rtmpdump && $(MAKE) rtmpdump SYS=darwin
	cd ext/rtmpdump && install_name_tool -change /usr/local/lib/librtmp.0.dylib @executable_path/librtmp/librtmp.0.dylib rtmpdump

clean:
	cd ext/rtmpdump && $(MAKE) clean

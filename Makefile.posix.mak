all:
	cd ext/rtmpdump && $(MAKE) rtmpdump SYS=posix XLDFLAGS=-Wl,-rpath=\\'$$$$ORIGIN/librtmp'

clean:
	cd ext/rtmpdump && $(MAKE) clean

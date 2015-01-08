UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),Darwin)

all:
	cd ext/rtmpdump && $(MAKE) rtmpdump SYS=darwin
	cd ext/rtmpdump && install_name_tool -change /usr/local/lib/librtmp.0.dylib @executable_path/librtmp/librtmp.0.dylib rtmpdump

clean:
	cd ext/rtmpdump && $(MAKE) clean

else

all:
	cd ext/rtmpdump && $(MAKE) rtmpdump SYS=posix XLDFLAGS=-Wl,-rpath=\\'$$$$ORIGIN/librtmp'

clean:
	cd ext/rtmpdump && $(MAKE) clean

endif

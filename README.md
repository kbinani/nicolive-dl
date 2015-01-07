# nicolive-dl

A command line tool to download nicolive TS(time-shift), written in Ruby.

# How to build

## OSX

```
git submodule update --init --recursive
make -f Makefile.osx.mak
```

## Windows

```
git submodule update --init --recursive
nmake -f Makefile.msvc.mak
```

## Linux

```
git submodule update --init --recursive
nmake -f Makefile.posix.mak
```

# How to use

```
$ bin/nicolive-dl --liveid=lv12345 --email=your_login_email@example.com --output=out.flv
Enter password for user: your_login_email@example.com
# Enter password, then hit return key.
```

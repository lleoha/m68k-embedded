#!/bin/sh

while getopts "j:p:" opt; do
    case $opt in
        j)
            OPTTHREADS=${OPTARG}
            ;;
        p)
            OPTPREFIX=${OPTARG}
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            ;;
    esac
done

THREADS=${OPTTHREADS:-1}
PREFIX=${OPTPREFIX:-/usr/local}
TARGET=m68k-elf
BINUTILS_PACKAGE=binutils-2.24
GCC_PACKAGE=gcc-4.9.1
NEWLIB_PACKAGE=newlib-2.1.0
GDB_PACKAGE=gdb-7.8

download_and_extract() {
    local BINUTILS_URL=https://ftp.gnu.org/gnu/binutils
    local BINUTILS_ARCH=${BINUTILS_PACKAGE}.tar.gz

    local GCC_URL=https://ftp.gnu.org/gnu/gcc/${GCC_PACKAGE}
    local GCC_ARCH=${GCC_PACKAGE}.tar.gz

    local NEWLIB_URL=ftp://sourceware.org/pub/newlib
    local NEWLIB_ARCH=${NEWLIB_PACKAGE}.tar.gz

    local GDB_URL=https://ftp.gnu.org/gnu/gdb
    local GDB_ARCH=${GDB_PACKAGE}.tar.gz

    wget ${BINUTILS_URL}/${BINUTILS_ARCH}
    tar zxvf ${BINUTILS_ARCH}

    wget ${GCC_URL}/${GCC_ARCH}
    tar zxvf ${GCC_ARCH}

    wget ${NEWLIB_URL}/${NEWLIB_ARCH}
    tar zxvf ${NEWLIB_ARCH}
    cd ${NEWLIB_PACKAGE}

    patch -p0 <<'END'
--- newlib/libc/include/sys/config.h	23 Oct 2013 10:04:42 -0000	1.65
+++ newlib/libc/include/sys/config.h	15 Aug 2014 19:26:22 -0000
@@ -75,6 +75,10 @@
 #define _POINTER_INT short
 #endif
 
+#if defined(__m68k__) || defined(__mc68000__)
+#define _READ_WRITE_RETURN_TYPE _ssize_t
+#endif
+
 #ifdef ___AM29K__
 #define _FLOAT_RET double
 #endif
END

    cd ..

    wget ${GDB_URL}/${GDB_ARCH}
    tar zxvf ${GDB_ARCH}
}

build_binutils() {
    local BINUTILS_BUILD=${BINUTILS_PACKAGE}-build
    mkdir ${BINUTILS_BUILD}
    cd ${BINUTILS_BUILD}
    ../${BINUTILS_PACKAGE}/configure \
        --prefix=${PREFIX} \
        --target=${TARGET} \
        --disable-nls \
        --disable-libssp \
        --disable-shared \
        --enable-multilib
        --with-gnu-ld \
        --with-gnu-as \
        --with-newlib
    make -j${THREADS} && sudo make install
    cd ..
}

build_gcc_first() {
    local GCC_BUILD=${GCC_PACKAGE}-build-first
    mkdir ${GCC_BUILD}
    cd ${GCC_BUILD}
    ../${GCC_PACKAGE}/configure \
        --prefix=${PREFIX} \
        --target=${TARGET} \
        --disable-nls \
        --disable-shared \
        --disable-libssp \
        --disable-libstdcxx-pch \
        --enable-languages=c \
        --enable-multilib \
        --with-gnu-ld \
        --with-gnu-as \
        --with-system-zlib \
        --with-newlib \
	--without-headers
    make -j${THREADS} all-gcc && sudo make install-gcc
    cd ..
}

build_newlib() {
    local NEWLIB_BUILD=${NEWLIB_PACKAGE}-build
    mkdir ${NEWLIB_BUILD}
    cd ${NEWLIB_BUILD}
    ../${NEWLIB_PACKAGE}/configure            \
        --prefix=${PREFIX}                    \
        --target=${TARGET}                    \
        --disable-newlib-fvwrite-in-streamio  \
        --disable-newlib-fseek-optimization   \
        --disable-newlib-wide-orient          \
        --disable-newlib-supplied-syscalls    \
        --disable-newlib-unbuf-stream-opt     \
        --disable-nls                         \
        --enable-newlib-reent-small           \
        --enable-newlib-nano-malloc           \
        --enable-lite-exit                    \
        --enable-newlib-global-atexit         \
        --enable-target-optspace
    make -j${THREADS} && sudo make install
    cd ..
}

build_gcc_last() {
    local GCC_BUILD=${GCC_PACKAGE}-build-last
    mkdir ${GCC_BUILD}
    cd ${GCC_BUILD}
    ../${GCC_PACKAGE}/configure \
        --prefix=${PREFIX} \
        --target=${TARGET} \
        --disable-nls \
        --disable-shared \
        --disable-libssp \
        --enable-languages=c,c++ \
        --enable-multilib \
        --disable-libstdcxx-pch \
        --with-gnu-ld \
        --with-gnu-as \
        --with-system-zlib \
        --with-newlib
    make -j${THREADS} CFLAGS_FOR_TARGET="-Os -ffunction-sections -fdata-sections" CXXFLAGS_FOR_TARGET="-Os -ffunction-sections -fdata-sections -fno-exceptions" && sudo make install
    cd ..
}

build_gdb() {
    local GDB_BUILD=${GDB_PACKAGE}-build
    mkdir ${GDB_BUILD}
    cd ${GDB_BUILD}
    ../${GDB_PACKAGE}/configure \
        --prefix=${PREFIX} \
        --target=${TARGET} \
        --disable-nls \
        --disable-shared \
        --disable-libssp \
        --enable-multilib \
        --with-gnu-ld \
        --with-gnu-as \
        --with-newlib
    make -j${THREADS} && sudo make install
    cd ..
}

download_and_extract
build_binutils
build_gcc_first
build_newlib
build_gcc_last
build_gdb

#!/bin/sh
#
# Copyright (c) 2026 LLVM-Latest
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

set -e

unset HOST

while [ $# -gt 0 ]; do
    case "$1" in
    --host=*)
        HOST="${1#*=}"
        ;;
    *)
        PREFIX="$1"
        ;;
    esac
    shift
done
if [ -z "$PREFIX" ]; then
    echo $0 [--host=triple] dest
    exit 1
fi

mkdir -p "$PREFIX"
PREFIX="$(cd "$PREFIX" && pwd)"

: ${CORES:=$(nproc 2>/dev/null)}
: ${CORES:=$(sysctl -n hw.ncpu 2>/dev/null)}
: ${CORES:=4}

if [ ! -d zstd ]; then
    git clone --depth 1 https://github.com/facebook/zstd.git
fi

if command -v ninja >/dev/null; then
    CMAKE_GENERATOR="Ninja"
else
    : ${CORES:=$(nproc 2>/dev/null)}
    : ${CORES:=$(sysctl -n hw.ncpu 2>/dev/null)}
    : ${CORES:=4}

    case $(uname) in
    MINGW*)
        CMAKE_GENERATOR="MSYS Makefiles"
        ;;
    esac
fi

if [ -n "$HOST" ]; then
    CROSS_NAME=-$HOST

    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_C_COMPILER=$HOST-gcc"
    # CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CXX_COMPILER=$HOST-g++"
    case $HOST in
    *-mingw32)
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_NAME=Windows"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_RC_COMPILER=$HOST-windres"
        ;;
    *-linux*)
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_NAME=Linux"
        ;;
    *)
        echo "Unrecognized host $HOST"
        exit 1
        ;;
    esac
fi

if [ -n "$COMPILER_LAUNCHER" ]; then
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_C_COMPILER_LAUNCHER=$COMPILER_LAUNCHER"
    # CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CXX_COMPILER_LAUNCHER=$COMPILER_LAUNCHER"
fi

if [ "$(uname)" = "Darwin" ]; then
    if [ -n "$MACOS_REDIST" ]; then
        : ${MACOS_REDIST_ARCHS:=arm64 x86_64}
    else # single architecture
        : ${MACOS_REDIST_ARCHS:=$ARCH}
    fi
    ARCH_LIST=""
    NATIVE=
    for arch in $MACOS_REDIST_ARCHS; do
        if [ -n "$ARCH_LIST" ]; then
            ARCH_LIST="$ARCH_LIST;"
        fi
        ARCH_LIST="$ARCH_LIST$arch"
        if [ "$(uname -m)" = "$arch" ]; then
            NATIVE=1
        fi
    done
    if [ -z "$NATIVE" ]; then
        # If we're not building for the native arch, flag to CMake that we're
        # cross compiling, to let it build native versions of tools used
        # during the build.
        ARCH="$(echo $MACOS_REDIST_ARCHS | awk '{print $1}')"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_NAME=Darwin"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_PROCESSOR=$ARCH"
    fi

    : ${MACOS_REDIST_VERSION:=10.12}
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_OSX_ARCHITECTURES=$ARCH_LIST"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_OSX_DEPLOYMENT_TARGET=$MACOS_REDIST_VERSION"
fi

cd zstd

[ -z "$CLEAN" ] || rm -rf build$CROSS_NAME
mkdir -p build$CROSS_NAME
cd build$CROSS_NAME

cmake \
    ${CMAKE_GENERATOR+-G} "$CMAKE_GENERATOR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DZSTD_BUILD_PROGRAMS=OFF \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_TESTING=OFF \
    $CMAKEFLAGS \
    ..
cmake --build . -j$CORES
cmake --install . --prefix . --strip

# excluded lib/cmake/zstd lib/pkgconfig/libzstd.pc
if [ -d "bin" ]; then # Windows dynamic library
    mkdir -p "$PREFIX/bin"
    cp -r bin/libzstd.dll "$PREFIX/bin"
fi
mkdir -p "$PREFIX/include/zstd"
cp include/* "$PREFIX/include/zstd"
mkdir -p "$PREFIX/lib"
cp lib/libzstd* "$PREFIX/lib"

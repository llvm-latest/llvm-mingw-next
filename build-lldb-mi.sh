#!/bin/sh
#
# Copyright (c) 2020 Martin Storsjo
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

. ./logging.sh

: ${LLDB_MI_VERSION:=main}
BUILDDIR=build
unset HOST

if [ "$(uname)" != "Darwin" ]; then
    WITH_CLANG=1
fi

while [ $# -gt 0 ]; do
    case "$1" in
    --host=*)
        HOST="${1#*=}"
        ;;
    --with-clang)
        WITH_CLANG=1
        ;;
    --with-zlib)
        WITH_ZLIB=1
        ;;
    --with-zstd)
        WITH_ZSTD=1
        ;;
    *)
        PREFIX="$1"
        ;;
    esac
    shift
done
if [ -z "$PREFIX" ]; then
    echo $0 [--host=<triple>] dest
    exit 1
fi

mkdir -p "$PREFIX"
PREFIX="$(cd "$PREFIX" && pwd)"

if [ ! -d lldb-mi ]; then
    git clone https://github.com/lldb-tools/lldb-mi.git
    CHECKOUT=1
fi

if [ -n "$SYNC" ] || [ -n "$CHECKOUT" ]; then
    cd lldb-mi
    [ -z "$SYNC" ] || git fetch
    git checkout $LLDB_MI_VERSION
    cd ..
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

export LLVM_DIR="$PREFIX"

# Try to find/guess the builddir under the llvm buildtree next by.
# If LLVM was built without LLVM_INSTALL_TOOLCHAIN_ONLY, and the LLVM
# installation directory hasn't been stripped, we should point the build there.
# But as this isn't necessarily the case, point to the LLVM build directory
# instead (which hopefully hasn't been removed yet).
LLVM_SRC="$(pwd)/llvm-project/llvm"
if [ -d "$LLVM_SRC" ]; then
    SUFFIX=${HOST+-}$HOST
    DIRS=""
    cd llvm-project/llvm
    for dir in build*$SUFFIX; do
        if [ -z "$SUFFIX" ]; then
            case $dir in
            *linux*|*mingw32*)
                continue
                ;;
            esac
        fi
        if [ -d "$dir" ]; then
            DIRS="$DIRS $dir"
        fi
    done
    if [ -n "$DIRS" ]; then
        dir="$(ls -td $DIRS | head -1)"
        export LLVM_DIR="$LLVM_SRC/$dir"
        echo Using $LLVM_DIR as LLVM build dir
        break
    else
        # No build directory found; this is ok if the installed prefix is a
        # full (development) install of LLVM. Warn that we didn't find what
        # we were looking for.
        echo Warning, did not find a suitable LLVM build dir, assuming $PREFIX contains LLVM development files >&2
    fi
    cd ../..
fi

if [ -n "$HOST" ]; then
    ARCH="${HOST%%-*}"
    BUILDDIR=$BUILDDIR-$HOST

    if [ -n "$WITH_CLANG" ]; then
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_C_COMPILER=clang"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CXX_COMPILER=clang++"
        CMAKEFLAGS="$CMAKEFLAGS -DLLVM_USE_LINKER=${USE_LINKER:-lld}"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_ASM_COMPILER_TARGET=$HOST"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_C_COMPILER_TARGET=$HOST"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CXX_COMPILER_TARGET=$HOST"
        if command -v $HOST-strip >/dev/null; then
            CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_STRIP=$(command -v $HOST-strip)"
        fi
    else
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_C_COMPILER=$HOST-gcc"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CXX_COMPILER=$HOST-g++"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_PROCESSOR=$ARCH"
    fi
    case $HOST in
    *-mingw32)
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_NAME=Windows"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_RC_COMPILER=$HOST-windres"
        ;;
    *-linux*)
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_NAME=Linux"
        if [ -n "$ARCH" == "aarch64" ]; then
            LINUX_CROSS_AARCH64=1
        fi
        ;;
    *)
        echo "Unrecognized host $HOST"
        exit 1
        ;;
    esac

    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH=$LLVM_DIR"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY"
fi

if [ -n "$COMPILER_LAUNCHER" ]; then
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_C_COMPILER_LAUNCHER=$COMPILER_LAUNCHER"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CXX_COMPILER_LAUNCHER=$COMPILER_LAUNCHER"
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
        # cross compiling.
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_NAME=Darwin"
    fi

    : ${MACOS_REDIST_VERSION:=10.12}
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_OSX_ARCHITECTURES=$ARCH_LIST"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_OSX_DEPLOYMENT_TARGET=$MACOS_REDIST_VERSION"
fi

if [ -n "$WITH_ZLIB" ]; then
    CMAKEFLAGS="$CMAKEFLAGS -DLLVM_ENABLE_ZLIB=FORCE_ON"
    ZLIB_INCLUDE_DIR="$PREFIX/include/zlib-ng"
    ZLIB_LIB="$PREFIX/lib/libz.a"
    CMAKEFLAGS="$CMAKEFLAGS -DZLIB_INCLUDE_DIR=$ZLIB_INCLUDE_DIR"
    CMAKEFLAGS="$CMAKEFLAGS -DZLIB_LIBRARY=$ZLIB_LIB"
    # add custom zlib-ng include path to CFLAGS and CXXFLAGS
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_INCLUDE_PATH=$ZLIB_INCLUDE_DIR"
else
    CMAKEFLAGS="$CMAKEFLAGS -DLLVM_ENABLE_ZLIB=FORCE_ON"

    if [ -n "$LINUX_CROSS_AARCH64" ]; then
        ZLIB_INCLUDE_DIR="/usr/include"
        ZLIB_LIB="/usr/lib/aarch64-linux-gnu/libz.so"
        CMAKEFLAGS="$CMAKEFLAGS -DZLIB_INCLUDE_DIR=$ZLIB_INCLUDE_DIR"
        CMAKEFLAGS="$CMAKEFLAGS -DZLIB_LIBRARY=$ZLIB_LIB"
    fi
fi

if [ -n "$WITH_ZSTD" ]; then
    CMAKEFLAGS="$CMAKEFLAGS -DLLVM_ENABLE_ZSTD=FORCE_ON"
    CMAKEFLAGS="$CMAKEFLAGS -DLLVM_USE_STATIC_ZSTD=ON"
    ZSTD_INCLUDE_DIR="$PREFIX/include/zstd"
    ZSTD_LIB="$PREFIX/lib/libzstd.a"
    CMAKEFLAGS="$CMAKEFLAGS -Dzstd_INCLUDE_DIR=$ZSTD_INCLUDE_DIR"
    CMAKEFLAGS="$CMAKEFLAGS -Dzstd_LIBRARY=$ZSTD_LIB"
else
    CMAKEFLAGS="$CMAKEFLAGS -DLLVM_ENABLE_ZSTD=FORCE_ON"

    if [ -n "$LINUX_CROSS_AARCH64" ]; then
        ZSTD_INCLUDE_DIR="/usr/include"
        ZSTD_LIB="/usr/lib/aarch64-linux-gnu/libzstd.so"
        CMAKEFLAGS="$CMAKEFLAGS -Dzstd_INCLUDE_DIR=$ZSTD_INCLUDE_DIR"
        CMAKEFLAGS="$CMAKEFLAGS -Dzstd_LIBRARY=$ZSTD_LIB"
    fi
fi

cd lldb-mi

[ -z "$CLEAN" ] || rm -rf $BUILDDIR
mkdir -p $BUILDDIR
cd $BUILDDIR
[ -n "$NO_RECONF" ] || rm -rf CMake*
cmake \
    ${CMAKE_GENERATOR+-G} "$CMAKE_GENERATOR" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    $CMAKEFLAGS \
    ..

cmake --build . ${CORES:+-j${CORES}}
cmake --install . --strip

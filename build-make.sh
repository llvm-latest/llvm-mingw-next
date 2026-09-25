#!/bin/sh
#
# Copyright (c) 2018 Martin Storsjo
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

unset HOST

: ${MAKE_VERSION:=4.4.1}

while [ $# -gt 0 ]; do
    case "$1" in
    --host=*)
        HOST="${1#*=}"
        ;;
    --use-git)
        USE_GIT=1
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

if [ -z "$USE_GIT" ]; then
    download() {
        if command -v curl >/dev/null; then
            curl --retry 3 --retry-delay 5 --retry-all-errors -fSLO "$1"
        else
            wget -t 3 -w 5 "$1"
        fi
    }

    if [ ! -d make-$MAKE_VERSION ]; then
        if [ ! -e make-$MAKE_VERSION.tar.gz ]; then
            echo "Downloading make-$MAKE_VERSION.tar.gz ..."
            download https://ftpmirror.gnu.org/gnu/make/make-$MAKE_VERSION.tar.gz

            if [ $? -ne 0 ]; then
                echo "Error: Download make-$MAKE_VERSION.tar.gz failed."
                exit 1
            fi
        fi

        echo "Extracting make-$MAKE_VERSION.tar.gz ..."
        tar -zxf make-$MAKE_VERSION.tar.gz
    fi

    cd make-$MAKE_VERSION
else # use git
    if [ ! -d make ]; then
        git clone --depth 1 https://github.com/mirror/make.git
    fi

    cd make
    ./bootstrap
fi

if [ -n "$HOST" ]; then
    case $HOST in
    *-mingw32)
        TARGET_WINDOWS=1
        ;;
    esac
else
    case $(uname) in
    MINGW*)
        TARGET_WINDOWS=1
        ;;
    esac
fi

if [ -n "$HOST" ]; then
    CONFIGFLAGS="$CONFIGFLAGS --host=$HOST"
    CROSS_NAME=-$HOST
fi

[ -z "$CLEAN" ] || rm -rf build$CROSS_NAME
mkdir -p build$CROSS_NAME
cd build$CROSS_NAME

CFLAGS="-std=gnu17 -O2"
LDFLAGS="-flto -ffunction-sections -fdata-sections -fno-unwind-tables"
if [ "$(uname)" = "Darwin" ]; then
    LDFLAGS="$LDFLAGS -Wl,-dead_strip -Wl,-dead_strip_dylibs"
else
    LDFLAGS="$LDFLAGS -Wl,-s -Wl,--gc-sections"
fi

# check mold linker on Linux
if [ "$(uname)" = "Linux" ] && [ -z "$TARGET_WINDOWS" ]; then
    if command -v mold >/dev/null; then
        LDFLAGS="$LDFLAGS -fuse-ld=mold"
    fi
fi

../configure --prefix="$PREFIX" $CONFIGFLAGS \
    --program-prefix=mingw32- \
    --enable-job-server \
    CFLAGS="$CFLAGS" \
    LDFLAGS="$LDFLAGS"

make -j$CORES
make install-binPROGRAMS
mkdir -p "$PREFIX/share/make"
install -m644 ../COPYING "$PREFIX/share/make/COPYING.txt"

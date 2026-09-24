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

if [ ! -d make ]; then
    git clone --depth 1 https://github.com/mirror/make.git
fi

cd make
./bootstrap

if [ -n "$HOST" ]; then
    CONFIGFLAGS="$CONFIGFLAGS --host=$HOST"
    CROSS_NAME=-$HOST
fi

[ -z "$CLEAN" ] || rm -rf build$CROSS_NAME
mkdir -p build$CROSS_NAME
cd build$CROSS_NAME

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
    CFLAGS="-O2" \
    LDFLAGS="$LDFLAGS"

make -j$CORES
make install-binPROGRAMS
mkdir -p "$PREFIX/share/make"
install -m644 ../COPYING "$PREFIX/share/make/COPYING.txt"

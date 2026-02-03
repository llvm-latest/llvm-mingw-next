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

unset HOST

while [ $# -gt 0 ]; do
    case "$1" in
    --host=*)
        HOST="${1#*=}"
        ;;
    --move-llvm)
        MOVE_LLVM=1
        ;;
    *)
        PREFIX="$1"
        ;;
    esac
    shift
done
if [ -z "$PREFIX" ]; then
    echo $0 [--host=triple] dir
    exit 1
fi

if [ -n "$FULL_LLVM" ]; then
    exit 0
fi

PREFIX="$(cd "$PREFIX" && pwd)"
cd "$PREFIX"

if [ -n "$MOVE_LLVM" ]; then
    remove_or_move() {
        local file="$1"
        local abs_path="$(pwd)/$file"
        local relative_path="${abs_path#$PREFIX/}"
        local dest="$(dirname "$PREFIX")/llvm-libs/$relative_path"
        local dest_dir="$(dirname "$dest")"
        echo "Moving $relative_path -> $dest"
        mkdir -p "$dest_dir"
        mv "$file" "$dest"
    }
else
    remove_or_move() {
        local file="$1"
        local abs_path="$(pwd)/$file"
        local relative_path="${abs_path#$PREFIX/}"
        echo "Removing $relative_path"
        rm -rf "$file"
    }
fi

if [ -n "$HOST" ]; then
    case $HOST in
    *-mingw32)
        EXEEXT=.exe
        ;;
    esac
fi

case $(uname) in
MINGW*)
    EXEEXT=.exe
    ;;
esac

echo "===== Stripping LLVM ====="

cd bin
for i in amdgpu-arch bugpoint c-index-test clang-* clangd clangd-* darwin-debug diagtool dsymutil find-all-symbols git-clang-format hmaptool ld64.lld* llc lldb-* lli llvm-* modularize nvptx-arch obj2yaml offload-arch opt pp-trace sancov sanstats scan-build scan-view split-file verify-uselistorder wasm-ld yaml2* libclang.dll *LTO.dll *Remarks.dll *.bat; do
    basename=$i
    if [ -n "$EXEEXT" ]; then
        # Some in the list are expanded globs, some are plain names we list.
        basename=${i%$EXEEXT}
        i=$basename
        if [ -e $basename$EXEEXT ]; then
            i=$basename$EXEEXT
        fi
    fi
    # Basename has got $EXEEXT stripped, but any other suffix kept intact.
    case $basename in
    *.sh)
        ;;
    clang++|clang-*.*|clang-cpp)
        ;;
    clang-format|git-clang-format)
        ;;
    clangd)
        ;;
    clang-scan-deps)
        ;;
    clang-tidy)
        ;;
    clang-target-wrapper*|clang-scan-deps-wrapper*)
        ;;
    clang-*)
        suffix="${basename#*-}"
        # Test removing all numbers from the suffix; if it is empty, the suffix
        # was a plain number (as if the original name was clang-7); if it wasn't
        # empty, remove the tool.
        if [ "$(echo $suffix | tr -d '[0-9]')" != "" ]; then
            remove_or_move $i
        fi
        ;;
    libclang.dll)
        ;;
    llvm-ar|llvm-cvtres|llvm-dlltool|llvm-nm|llvm-objdump|llvm-ranlib|llvm-rc|llvm-readobj|llvm-strings|llvm-pdbutil|llvm-objcopy|llvm-strip|llvm-cov|llvm-profdata|llvm-addr2line|llvm-symbolizer|llvm-wrapper|llvm-windres|llvm-ml|llvm-readelf|llvm-size|llvm-cxxfilt|llvm-lib)
        ;;
    ld64.lld|wasm-ld)
        if [ -e $i ]; then
            remove_or_move $i
        fi
        ;;
    lldb|lldb-server|lldb-argdumper|lldb-instr|lldb-mi|lldb-vscode|lldb-dap)
        ;;
    *)
        if [ -f $i ]; then
            remove_or_move $i
        elif [ -L $i ] && [ ! -e $(readlink $i) ]; then
            # Remove dangling symlinks
            remove_or_move $i
        fi
        ;;
    esac
done
if [ -n "$EXEEXT" ]; then
    # Convert ld.lld from a symlink to a regular file, so we can remove
    # the one it points to. On MSYS, and if packaging built toolchains
    # in a zip file, symlinks are converted into copies.
    if [ -L ld.lld$EXEEXT ]; then
        cp ld.lld$EXEEXT tmp
        rm ld.lld$EXEEXT
        mv tmp ld.lld$EXEEXT
    fi
    # lld-link isn't used normally, but can be useful for debugging/testing,
    # and is kept in unix setups. Removing it when packaging for windows,
    # to conserve space.
    rm -fv lld$EXEEXT lld-link$EXEEXT
    # Remove superfluous frontends; these aren't really used.
    rm -fv clang-cpp* clang++*
fi
cd ..
remove_or_move libexec
cd share
cd clang
for i in *; do
    case $i in
    clang-format*)
        ;;
    *)
        remove_or_move $i
        ;;
    esac
done
cd ..
rm -rf opt-viewer scan-build scan-view
rm -rf man/man1/scan-build*
cd ..
cd include
remove_or_move lld
cd ..
cd lib
for i in lib*.a; do
    case $i in
    libclang.dll.a|libclang-cpp*|liblldb*|libLLVM-[0-9]*)
        ;;
    libzstd.*) # thirdparty libs
        ;;
    *)
        remove_or_move $i
        ;;
    esac
done
for i in *.so* *.dylib* cmake; do
    case $i in
    libclang.so*|libclang.dylib*|libclang-cpp*|liblldb*|libLLVM*)
        ;;
    LLVMgold*)
        ;;
    *)
        remove_or_move $i
        ;;
    esac
done
cd ..

echo "===== End Strip LLVM ====="

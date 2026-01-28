#!/bin/sh

set -e

# Install Essential Tools
apt-get update -qq
apt-get install -qy -o Dpkg::Use-Pty=0 \
    wget curl software-properties-common \
    git git-lfs \
    build-essential binutils binutils-dev \
    clang lld llvm gcc g++ make cmake ninja-build \
    python3 python3-pip nasm \
    autoconf automake autopoint libtool pkg-config \
    zip unzip bzip2 xz-utils p7zip-full \
    gettext less
apt-get clean -y

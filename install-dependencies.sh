#!/bin/sh

set -e

# Install apt-fast
apt-get update -qq
apt-get install -y -o Dpkg::Use-Pty=0 software-properties-common
add-apt-repository ppa:apt-fast/stable
apt-get update -qq
apt-get install -y -o Dpkg::Use-Pty=0 apt-fast

# Install Essential Tools
apt-fast install -y -o Dpkg::Use-Pty=0 \
    wget curl software-properties-common \
    git git-lfs \
    build-essential binutils binutils-dev ccache \
    clang lld llvm gcc g++ make cmake ninja-build \
    python3 python3-pip nasm \
    autoconf automake autopoint libtool pkg-config \
    zip unzip bzip2 xz-utils p7zip-full \
    gettext less

apt-get clean -y

git config --global http.retry 3

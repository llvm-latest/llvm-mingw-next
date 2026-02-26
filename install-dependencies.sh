#!/bin/sh

set -e

if [ "$CI" = "true" ]; then
    sudo rm -rf /etc/apt/apt-mirrors.txt
    sudo rm -rf /etc/apt/sources.list.d

    sudo tee /etc/apt/sources.list > /dev/null <<EOF
deb https://archive.ubuntu.com/ubuntu/ devel main restricted universe multiverse
# deb-src https://archive.ubuntu.com/ubuntu/ devel main restricted universe multiverse

deb https://archive.ubuntu.com/ubuntu/ devel-updates main restricted universe multiverse
# deb-src https://archive.ubuntu.com/ubuntu/ devel-updates main restricted universe multiverse

deb https://archive.ubuntu.com/ubuntu/ devel-backports main restricted universe multiverse
# deb-src https://archive.ubuntu.com/ubuntu/ devel-backports main restricted universe multiverse

deb https://archive.ubuntu.com/ubuntu/ devel-security main restricted universe multiverse
# deb-src https://archive.ubuntu.com/ubuntu/ devel-security main restricted universe multiverse

deb https://archive.ubuntu.com/ubuntu/ devel-proposed main restricted universe multiverse
# deb-src https://archive.ubuntu.com/ubuntu/ devel-proposed main restricted universe multiverse
EOF
fi

# Install apt-fast
if [ -f /.dockerenv ] || grep -q 'docker\|lxc' /proc/1/cgroup 2>/dev/null; then
    sudo apt-get update -qq
    sudo apt-get install -y -o Dpkg::Use-Pty=0 software-properties-common
fi
sudo add-apt-repository ppa:apt-fast/stable
sudo apt-get update -qq
sudo apt-get install -y -o Dpkg::Use-Pty=0 apt-fast

# Install Essential Tools
sudo apt-fast install -y -o Dpkg::Use-Pty=0 \
    wget curl software-properties-common \
    git git-lfs \
    build-essential binutils binutils-dev \
    clang lld llvm gcc g++ make cmake ninja-build \
    python3 python3-pip nasm \
    autoconf automake autopoint libtool pkg-config \
    zip unzip bzip2 xz-utils p7zip-full 7zip \
    gettext less

sudo apt-get clean -y

git config --global http.retry 3

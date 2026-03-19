#!/bin/sh

set -e

while [ $# -gt 0 ]; do
    case "$1" in
    --with-arm64)
        WITH_ARM64=1
        ;;
    *)
        echo Unrecognized parameter $1
        exit 1
        ;;
    esac
    shift
done

if [ "$CI" = "true" ]; then
    sudo rm -rf /etc/apt/apt-mirrors.txt
    sudo rm -rf /etc/apt/sources.list.d

    if [ -n "$WITH_ARM64" ]; then
        sudo dpkg --add-architecture arm64
        sudo tee /etc/apt/sources.list > /dev/null <<EOF
deb [arch=amd64] https://archive.ubuntu.com/ubuntu/ devel main restricted universe multiverse
deb [arch=amd64] https://archive.ubuntu.com/ubuntu/ devel-backports main restricted universe multiverse
deb [arch=amd64] https://archive.ubuntu.com/ubuntu/ devel-proposed main restricted universe multiverse
deb [arch=amd64] https://archive.ubuntu.com/ubuntu/ devel-security main restricted universe multiverse
deb [arch=amd64] https://archive.ubuntu.com/ubuntu/ devel-updates main restricted universe multiverse
deb [arch=arm64] https://ports.ubuntu.com/ubuntu-ports/ devel main restricted universe multiverse
deb [arch=arm64] https://ports.ubuntu.com/ubuntu-ports/ devel-backports main restricted universe multiverse
deb [arch=arm64] https://ports.ubuntu.com/ubuntu-ports/ devel-proposed main restricted universe multiverse
deb [arch=arm64] https://ports.ubuntu.com/ubuntu-ports/ devel-security main restricted universe multiverse
deb [arch=arm64] https://ports.ubuntu.com/ubuntu-ports/ devel-updates main restricted universe multiverse
EOF
    else
        sudo tee /etc/apt/sources.list > /dev/null <<EOF
deb https://archive.ubuntu.com/ubuntu/ devel main restricted universe multiverse
deb https://archive.ubuntu.com/ubuntu/ devel-backports main restricted universe multiverse
deb https://archive.ubuntu.com/ubuntu/ devel-proposed main restricted universe multiverse
deb https://archive.ubuntu.com/ubuntu/ devel-security main restricted universe multiverse
deb https://archive.ubuntu.com/ubuntu/ devel-updates main restricted universe multiverse
EOF
    fi
fi

# Install apt-fast
sudo add-apt-repository ppa:apt-fast/stable -y
# sudo apt-get update -qq
sudo apt-get install -y -o Dpkg::Use-Pty=0 apt-fast

if [ -f /.dockerenv ] || grep -q 'docker\|lxc' /proc/1/cgroup 2>/dev/null; then
    sudo apt-get install -y -o Dpkg::Use-Pty=0 software-properties-common
fi

# Install Essential Tools
sudo apt-fast install -y -o Dpkg::Use-Pty=0 \
    wget curl software-properties-common \
    git git-lfs \
    build-essential binutils binutils-dev \
    clang lld llvm gcc g++ make cmake ninja-build \
    python3 python3-pip nasm \
    autoconf automake autopoint libtool pkg-config \
    zip unzip bzip2 xz-utils p7zip-full 7zip \
    zlib1g-dev libzstd-dev \
    gettext less

# Install arm64 dependencies
if [ -n "$WITH_ARM64" ]; then
sudo apt-fast install -y -o Dpkg::Use-Pty=0 \
    binutils-dev:arm64 \
    zlib1g-dev:arm64 libzstd-dev:arm64
fi

sudo apt-get clean -y

git config --global http.retry 3

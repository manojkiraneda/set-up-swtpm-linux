#!/usr/bin/bash

# Install required dependencies
sudo apt install git-email\
	         libaio-dev \
		 libbluetooth-dev \
		 libcapstone-dev \
		 libbrlapi-dev \
		 libbz2-dev \
		 libcap-ng-dev \
		 libgtk-3-dev \
		 libibverbs-dev \
		 libjpeg8-dev \
		 libncurses5-dev \
		 libnuma-dev \
		 librbd-dev \
		 librdmacm-dev \
		 libsasl2-dev \
		 libsdl2-dev \
		 libseccomp-dev \
		 libsnappy-dev \
		 libssh-dev \
		 libvde-dev \
		 libvdeplug-dev \
		 libvte-2.91-dev \
		 libxen-dev \
		 liblzo2-dev \
		 valgrind \
		 xfslibs-dev \
		 python3-pip \
		 python3-setuptools \
		 libslirp-dev

# Download openbmc/qemu source code
git clone https://github.com/openbmc/qemu.git ~/openbmc-qemu
cd ~/openbmc-qemu
./configure --target-list=arm-softmmu --enable-slirp
ninja -C build
cd build
ninja install

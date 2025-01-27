#!/usr/bin/bash

# Install all the dependencies
sudo apt -y update
sudo apt -y install \
	    autoconf-archive \
	    libcmocka0 \
	    libcmocka-dev \
	    procps \
	    iproute2 \
	    build-essential \
	    git \
	    pkg-config \
	    gcc \
	    libtool \
	    automake \
	    libssl-dev \
	    uthash-dev \
	    autoconf \
	    doxygen \
	    libjson-c-dev \
	    libini-config-dev \
	    libcurl4-openssl-dev \
	    libltdl-dev \
	    libglib2.0-dev \
	    expect \
		dh-autoreconf \
		libtasn1-6-dev \
		net-tools \
		libgnutls28-dev \
		gawk \
		socat \
		libfuse-dev \
		libseccomp-dev \
		make \
		libjson-glib-dev \
		gnutls-bin


function check_continue()
{   while true; do
   	read -p "Do you want to continue? (y/n) " yn
   	case $yn in
       		[Yy]* ) break;;
       		[Nn]* ) exit;;
       		* ) echo "Please answer yes or no.";;
   	esac
done
}

# Install tpm-tss software
git clone https://github.com/tpm2-software/tpm2-tss ~/tpm2-tss
cd ~/tpm2-tss
git checkout 4.1.3
./bootstrap
./configure
make -j$(nproc)
sudo make install
sudo ldconfig

# Install tpm-tools software
git clone https://github.com/tpm2-software/tpm2-tools ~/tpm2-tools
cd ~/tpm2-tools
git checkout 5.7
./bootstrap
./configure
make -j$(nproc)
sudo make install
sudo ldconfig

# Install tpm2-openssl for tpm2 provider support
git clone https://github.com/tpm2-software/tpm2-openssl ~/tpm2-openssl
cd ~/tpm2-openssl
git checkout 1.2.0
./bootstrap
./configure
make -j$(nproc)
sudo make install
sudo ldconfig

# Install libtpms-devel
git clone https://github.com/stefanberger/libtpms ~/libtpms
cd ~/libtpms
git checkout v0.9.6
./autogen.sh --with-tpm2 --with-openssl
make -j$(nproc)
sudo make install
sudo ldconfig

# Install Libtpms-based TPM emulator
git clone https://github.com/stefanberger/swtpm ~/swtpm
cd ~/swtpm
git checkout v0.8.2
./autogen.sh --with-openssl --without-seccomp --prefix=/usr
make -j$(nproc)
sudo make install
sudo ldconfig

# Start the tpm emultor and setup
mkdir -p /tmp/emulated_tpm

# Create configuration files for swtpm_setup:
# - ~/.config/swtpm_setup.conf
# - ~/.config/swtpm-localca.conf
#   This file specifies the location of the CA keys and certificates:
#   - ~/.config/var/lib/swtpm-localca/*.pem
# - ~/.config/swtpm-localca.options
swtpm_setup --tpm2 --create-config-files overwrite,root

# Initialize the swtpm
swtpm_setup --tpm2 --config ~/.config/swtpm_setup.conf --tpm-state /tmp/emulated_tpm --overwrite --create-ek-cert --create-platform-cert --write-ek-cert-files /tmp/emulated_tpm

# Define variables
SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SERVICE_DIR/tpm-server.service"

# Ensure the directory exists
mkdir -p "$SERVICE_DIR"

# Create the service file with the provided content
cat <<EOL > "$SERVICE_FILE"
[Unit]
Description=TPM2.0 Simulator Server daemon

[Service]
ExecStartPre=/usr/bin/mkdir -p /tmp/emulated_tpm
ExecStart=/usr/bin/swtpm socket --tpm2 --flags not-need-init --tpmstate dir=/tmp/emulated_tpm --ctrl type=unixio,path=/tmp/emulated_tpm/swtpm-sock
Restart=always
Environment=PATH=/usr/bin:/usr/local/bin

[Install]
WantedBy=default.target
EOL

# Reload systemd to recognize the new service
systemctl --user daemon-reload

# Enable the service
systemctl --user enable tpm-server.service

# Start the service
systemctl --user start tpm-server.service

# Confirm the service status
systemctl --user status tpm-server.service

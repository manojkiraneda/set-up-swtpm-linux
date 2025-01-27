#!/usr/bin/bash

# Check if the required argument (remote username and host) is provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <username@hostname> [image_size]"
    exit 1
fi

# Input arguments
REMOTE_HOST=$1
IMAGE_SIZE=${2:-16G}  # Default image size is 16G if not provided

# Define variables
REPO_URL="https://github.com/openbmc/openbmc.git"
REMOTE_HOME="/home/$(echo $REMOTE_HOST | cut -d'@' -f1)"
REMOTE_REPO_PATH="$REMOTE_HOME/master/openbmc"
REMOTE_PATCH_DIR="$REMOTE_REPO_PATH/meta-ibm/recipes-kernel/linux/linux-aspeed/"
PATCH_FILE="0001-Add-TPM-to-rainier-device-tree.patch"
BBAPPEND_FILE="$REMOTE_REPO_PATH/meta-ibm/recipes-kernel/linux/linux-aspeed_%.bbappend"
LOCAL_CONF="$REMOTE_REPO_PATH/build/p10bmc/conf/local.conf"
BUILD_PATH="$REMOTE_REPO_PATH/build/p10bmc/tmp/deploy/images/p10bmc/"
MMC_IMAGE="mmc-p10bmc.img"

# Clone the OpenBMC repository on the remote server
ssh "$REMOTE_HOST" <<EOF
if [ ! -d "$REMOTE_REPO_PATH" ]; then
    echo "Cloning OpenBMC repository..."
    git clone "$REPO_URL" "$REMOTE_REPO_PATH"
else
    echo "Repository already exists. Skipping clone."
fi
EOF

# Copy the patch file to the remote server
echo "Copying patch file to remote server..."
scp "$PATCH_FILE" "$REMOTE_HOST:$REMOTE_PATCH_DIR"

# Update the bbappend file on the remote server
echo "Updating bbappend file on remote server..."
ssh "$REMOTE_HOST" <<EOF
if ! grep -q "file://0001-Add-TPM-to-rainier-device-tree.patch" "$BBAPPEND_FILE"; then
    echo "Appending patch entry to bbappend file..."
    echo "SRC_URI:append:p10bmc = \" file://0001-Add-TPM-to-rainier-device-tree.patch\"" >> "$BBAPPEND_FILE"
else
    echo "Patch entry already exists in bbappend file. Skipping update."
fi
EOF

# Run setup and bitbake commands inside the openbmc folder, redirecting bitbake output to local machine
echo "Running setup and bitbake commands on the remote server..."
ssh "$REMOTE_HOST" <<EOF
cd "$REMOTE_REPO_PATH"
. setup p10bmc
echo "DISTRO_FEATURES += \" tpm2\"" >> "$LOCAL_CONF"
echo "IMAGE_INSTALL += \" tpm2-tools tpm2-openssl tpm2-tss libtss2-tcti-device\"" >> "$LOCAL_CONF"
bitbake obmc-phosphor-image
EOF

# Ensure required tools are available
for cmd in scp dd truncate xz; do
    if ! command -v $cmd &>/dev/null; then
        echo "Error: Required command '$cmd' not found. Please install it and try again."
        exit 1
    fi
done

# Define firmware directory and xz decompression tool
FW_DIR="."
XZDEC="xzcat"  # Use xzcat for decompression

# Copy artifacts from the build
echo "Copying artifacts from the build directory on the remote server..."
scp "$REMOTE_HOST:$BUILD_PATH/u-boot-spl.bin" .
scp "$REMOTE_HOST:$BUILD_PATH/u-boot.bin" .
scp "$REMOTE_HOST:$BUILD_PATH/obmc-phosphor-image-p10bmc.wic.xz" .

# Check if files were successfully copied
if [ ! -f u-boot-spl.bin ] || [ ! -f u-boot.bin ] || [ ! -f obmc-phosphor-image-p10bmc.wic.xz ]; then
    echo "Error: Failed to copy one or more required files from the remote server."
    exit 1
fi

# Prepare the MMC image
echo "Creating MMC image..."
dd if=/dev/zero of=$MMC_IMAGE bs=1M count=128 status=progress
dd if=u-boot-spl.bin-p10bmc of=$MMC_IMAGE conv=notrunc
dd if=u-boot.bin-p10bmc of=$MMC_IMAGE conv=notrunc bs=1K seek=64
$XZDEC obmc-phosphor-image-p10bmc.wic.xz | dd of=$MMC_IMAGE conv=notrunc bs=1M seek=2 status=progress
truncate --size=$IMAGE_SIZE $MMC_IMAGE

echo "MMC image creation completed successfully: $MMC_IMAGE"



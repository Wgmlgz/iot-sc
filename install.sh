#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Function to configure apt and install dependencies
configure_apt() {
    echo "Updating apt and installing necessary packages..."
    sudo apt update
    sudo apt install git unzip jq -y
}

# Function to install Docker
install_docker() {
    echo "Installing Docker..."
    sudo apt-get install ca-certificates curl -y
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |
        sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
}

# Function to install ThingsBoard Gateway
install_thingsboard_gateway() {
    cd /tmp
    wget https://github.com/thingsboard/thingsboard-gateway/releases/latest/download/python3-thingsboard-gateway.deb
    sudo apt install ./python3-thingsboard-gateway.deb -y
    USER="thingsboard_gateway"
    CMD="/bin/systemctl reboot"
    FILE="/etc/sudoers"
    cp $FILE ${FILE}.bak
    grep -q "${USER} ALL=(ALL) NOPASSWD: ${CMD}" $FILE
    if [ $? -eq 0 ]; then
        echo "Entry already exists, no changes made."
    else
        echo "${USER} ALL=(ALL) NOPASSWD: ${CMD}" | sudo EDITOR="tee -a" visudo >/dev/null
        if [ $? -eq 0 ]; then
            echo "Sudoers file updated successfully."
        else
            echo "Failed to update sudoers file. Restoring backup."
            cp ${FILE}.bak $FILE
        fi
    fi
    sudo usermod -a -G sudo thingsboard_gateway
}

# Function to configure directories
configure_directories() {
    echo "Configuring directories and updating configurations..."

    # Define the directory and file paths
    IOT_SC_DIR="/etc/iot-sc"
    CONFIG_FILE="$IOT_SC_DIR/config.json"
    EXAMPLE_CONFIG_FILE="$HOME/iot-sc/example.config.json"
    TB_GATEWAY_CONFIG_FILE="/etc/thingsboard-gateway/config/tb_gateway.json"

    # Create the iot-sc directory if it doesn't exist
    mkdir -p $IOT_SC_DIR
    chmod 777  $IOT_SC_DIR


    # Merge the existing config with the example config
    if [ -f "$CONFIG_FILE" ]; then
        echo "Merging existing configuration with default configuration..."
        jq -s '.[0] * .[1]' "$EXAMPLE_CONFIG_FILE" "$CONFIG_FILE" >"$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    else
        echo "No existing configuration found. Using default configuration..."
        cp "$EXAMPLE_CONFIG_FILE" "$CONFIG_FILE"
    fi

    # Validate and update the ThingsBoard Gateway configuration
    if [ -f "$CONFIG_FILE" ] && [ -f "$TB_GATEWAY_CONFIG_FILE" ]; then
        echo "Updating ThingsBoard Gateway configuration..."
        HOST=$(jq -r '.host' "$CONFIG_FILE")
        ACCESS_TOKEN=$(jq -r '.auth_token' "$CONFIG_FILE")

        jq ".thingsboard.host = \"$HOST\" |
            .thingsboard.security.accessToken = \"$ACCESS_TOKEN\" |
            .thingsboard.remoteShell = true" "$TB_GATEWAY_CONFIG_FILE" >"$TB_GATEWAY_CONFIG_FILE.tmp" && mv "$TB_GATEWAY_CONFIG_FILE.tmp" "$TB_GATEWAY_CONFIG_FILE"
    else
        echo "Required configuration files are missing."
        exit 1
    fi
    systemctl restart thingsboard-gateway
    echo "Configuration process completed successfully."
}

# Function to install the update agent
install_update_agent() {
    echo "Installing Update Agent..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    cd $HOME/iot-sc/update-agent
    cargo build --release
    bash ./src/post_install.sh
}

main() {
    configure_apt
    install_docker
    install_thingsboard_gateway
    configure_directories
    install_update_agent
}

# Run the main function
main
# cd ~
# curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
# unzip awscliv2.zip
# sudo ./aws/install

# install swUpdate
# sudo apt install swupdate
# Install necessary libraries
# sudo apt-get install -y \
#     build-essential \
#     pkg-config \
#     libncurses5-dev \
#     libncursesw5-dev \
#     libssl-dev \
#     libconfig-dev \
#     libjson-c-dev \
#     zlib1g-dev \
#     liblzma-dev \
#     liblzo2-dev \
#     libubootenv-tool \
#     libmtd-dev \
#     libcurl4-openssl-dev \
#     lua5.3

# export PKG_CONFIG_PATH=/usr/lib/arm-linux-gnueabihf/pkgconfig:$PKG_CONFIG_PATH

# cd /usr/lib/arm-linux-gnueabihf/pkgconfig
# sudo ln -s lua-5.3.pc lua.pc

# cd ~/swupdate
# # # Install additional tools that might be useful for debugging or additional support
# sudo apt-get install -y \
#     curl \
#     git

# sudo apt-get install mtd-utils libmtd-dev mtd-utils  libubi-dev libarchive-dev

# # # Confirm installation
# echo "All necessary dependencies for SWUpdate have been installed."

# cd ~
# # git clone https://github.com/sbabic/swupdate.git
# cd swupdate
# make menuconfig
# make
# make install
# swupdate -l 5 -w '-r ./examples/www/v2 -p 8080'

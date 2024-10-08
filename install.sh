#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Store the current directory
original_dir=$(pwd)

# Function to configure apt and install dependencies
configure_apt() {
    echo "Updating apt and installing necessary packages..."
    sudo apt update
    sudo apt install git unzip jq python3 ffmpeg v4l-utils -y
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
    sudo apt-get update
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
}

# Function to install ThingsBoard Gateway
install_thingsboard_gateway() {
    cd /tmp
    wget https://github.com/thingsboard/thingsboard-gateway/releases/latest/download/python3-thingsboard-gateway.deb
    sudo apt install ./python3-thingsboard-gateway.deb -y
    TBUSER="thingsboard_gateway"
    RCMD="/bin/systemctl reboot"
    SFILE="/etc/sudoers"
    cp $SFILE ${SFILE}.bak

    set +e
    grep -q "${TBUSER} ALL=(ALL) NOPASSWD: ${RCMD}" $SFILE
    result=$?
    set -e

    echo "Updating Thingsboard gateway user"
    if [ $result -eq 0 ]; then
        echo "Entry already exists, no changes made."
    else
        echo "${TBUSER} ALL=(ALL) NOPASSWD: ${RCMD}" | sudo EDITOR="tee -a" visudo >/dev/null
        if [ $? -eq 0 ]; then
            echo "Sudoers file updated successfully."
        else
            echo "Failed to update sudoers file. Restoring backup."
            cp ${SFILE}.bak $SFILE
        fi
    fi
    sudo usermod -a -G sudo thingsboard_gateway
    echo "Thingsboard gateway installed"
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

    mkdir -p /opt/iot-sc
    chmod 777 /opt/iot-sc

    mkdir -p /opt/iot-sc/temp-update
    chmod 777 /opt/iot-sc/temp-update

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
        DEVICE_ID=$(jq -r '.device_id' "$CONFIG_FILE")
        AUTH_TOKEN=$(jq -r '.auth_token' "$CONFIG_FILE")

        echo "Device ID: '$DEVICE_ID'"
        echo "Auth Token: '$AUTH_TOKEN'"
         # Check if the device_id or auth_token is missing
        if [[ "$DEVICE_ID" = *"HERE"* || "$AUTH_TOKEN" = *"HERE"* ]]; then
            echo "One or more required configurations (device_id or auth_token) are missing."
            if [[ "$DEVICE_ID" = *"HERE"* ]]; then
                echo "Please enter the device_id:"
                read DEVICE_ID
                jq ".device_id = \"$DEVICE_ID\"" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
            fi
            if [[ "$AUTH_TOKEN" = *"HERE"* ]]; then
                echo "Please enter the auth_token:"
                read AUTH_TOKEN
                jq ".auth_token = \"$AUTH_TOKEN\"" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
            fi
            
            # Recursively call the function to reprocess with updated configs
            configure_directories
            return
        fi

        jq ".thingsboard.host = \"$HOST\" |
            .thingsboard.security.accessToken = \"$AUTH_TOKEN\" |
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
    # Restore the original directory
    cd "$original_dir"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    cd update-agent
    cargo build --release
    bash ./src/post_install.sh
}

install_main_service() {
   echo "Installing Engine ..."
   docker compose up --build --force-recreate -d
}

main() {
    configure_apt
    install_docker
    install_thingsboard_gateway
    configure_directories
    install_update_agent
    install_main_service
}

# Run the main function
main

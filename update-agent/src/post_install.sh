#!/bin/bash

# Define the installation directory and service name
INSTALL_DIR="/usr/local/bin"
SERVICE_NAME="update-agent"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# Step 1: Ensure the binary exists
if [ ! -f "./target/release/${SERVICE_NAME}" ]; then
    echo "Binary not found, make sure to build the project first."
    exit 1
fi

# Step 2: Copy the binary to the installation directory
echo "Installing the binary to ${INSTALL_DIR}..."
sudo cp ./target/release/${SERVICE_NAME} ${INSTALL_DIR}/${SERVICE_NAME}

# Step 3: Create the systemd service file
echo "Setting up systemd service..."
cat <<EOF | sudo tee ${SERVICE_FILE}
[Unit]
Description=Rust Update Agent
After=network.target

[Service]
ExecStart=${INSTALL_DIR}/${SERVICE_NAME}
User=root
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Step 4: Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable ${SERVICE_NAME}
sudo systemctl start ${SERVICE_NAME}

echo "Service ${SERVICE_NAME} has been installed and started."

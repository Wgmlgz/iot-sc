#!/bin/bash

set -e

# Script parameter for the update file path (assumed to be relative or absolute)
UPDATE_FILE_PATH="$1"

# Validate the input parameter
if [[ -z "$UPDATE_FILE_PATH" ]]; then
    echo "Usage: $0 <path-to-update-tar-file>"
    exit 1
fi

# Define paths
BASE_UPDATE_DIR="/opt/iot-sc/temp-update"

# Extract filename from the input path
UPDATE_FILE_NAME=$(basename "$UPDATE_FILE_PATH")
STORAGE_PATH="$BASE_UPDATE_DIR/$UPDATE_FILE_NAME"

# Copy the update package to the temp-update directory
if [[ -f "$UPDATE_FILE_PATH" ]]; then
    cp "$UPDATE_FILE_PATH" "$STORAGE_PATH"
else
    echo "Error: Update file does not exist at $UPDATE_FILE_PATH"
    exit 1
fi

# Main project directory
PROJECT_DIR="$HOME/iot-sc"
# Check for necessary commands
if ! command -v docker &> /dev/null; then
    echo "Error: docker command not found."
    exit 1
fi

# Extract the base name without extension for the directory
UPDATE_DIR_NAME=$(basename "$STORAGE_PATH" .tar.gz)
NEW_DIR_PATH="$BASE_UPDATE_DIR/$UPDATE_DIR_NAME/iot-sc"

# Create directory for new update
mkdir -p "$NEW_DIR_PATH"
rm -rf "$NEW_DIR_PATH/*"

# Extract the update package
echo "Extracting $STORAGE_PATH to $NEW_DIR_PATH..."
tar -xzf "$STORAGE_PATH" -C "$NEW_DIR_PATH" || exit 1

# # Copy new files to the project directory
# echo "Copying files to the project directory..."
# mv "$PROJECT_DIR/" "$PROJECT_DIR-backup" 
# cp -a "$NEW_DIR_PATH/." "$PROJECT_DIR/" || exit 1

# Clean up the new directory after update
# rm -rf "$NEW_DIR_PATH"

# Restart Docker services
echo "Restarting Docker services..."
cd "$NEW_DIR_PATH" || exit 1
docker compose down || exit 1
docker compose up -d --build --force-recreate|| exit 1

echo "Update successfully applied and services restarted."

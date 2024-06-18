#!/bin/bash

# Define the directory containing your project files
PROJECT_DIR="."

# Define where to save the archive
OUTPUT_DIR="./package"


# Extract firmware title and version from Python variables
read -r TITLE VERSION <<< $(python3 -c "import sys; from device.configuration import current_fw_title, current_fw_version; print(current_fw_title, current_fw_version)")

echo "Title: $TITLE"
echo "Version: $VERSION"

OUTPUT_FILE="$OUTPUT_DIR/${TITLE}_${VERSION}.tar.gz"

# Remove existing archive if it exists
if [ -f "$OUTPUT_FILE" ]; then
    echo "Removing old archive..."
    rm -f $OUTPUT_FILE
fi

# Create an archive of the project directory
mkdir -p $OUTPUT_DIR
tar -czf $OUTPUT_FILE --exclude='*.tar.gz' --exclude='temp*' --exclude='*.mp4' -C $PROJECT_DIR .

echo "Project packaged into $OUTPUT_FILE"

#!/bin/bash

# Define the directory containing your project files
PROJECT_DIR="."

# Define where to save the archive
OUTPUT_DIR="./package/"
VERSION="0.1-test"
OUTPUT_FILE="$OUTPUT_DIR/device_package_$VERSION.tar.gz"

# Remove existing archive if it exists
if [ -f "$OUTPUT_FILE" ]; then
    echo "Removing old archive..."
    rm -f $OUTPUT_FILE
fi

# Create an archive of the project directory
mkdir -p $OUTPUT_DIR
tar -czf $OUTPUT_FILE --exclude='*.tar.gz' --exclude='temp*' --exclude='*.mp4' -C $PROJECT_DIR .

echo "Project packaged into $OUTPUT_FILE"

#!/bin/bash

# Define user and command
USER="thingsboard_gateway"
CMD="/bin/systemctl reboot"
FILE="/etc/sudoers"

# Backup the existing sudoers file
cp $FILE ${FILE}.bak
grep -q "${USER} ALL=(ALL) NOPASSWD: ${CMD}" $FILE

if [ $? -eq 0 ]; then
    echo "Entry already exists, no changes made."
else
    echo "${USER} ALL=(ALL) NOPASSWD: ${CMD}" | sudo EDITOR="tee -a" visudo > /dev/null
    if [ $? -eq 0 ]; then
        echo "Sudoers file updated successfully."
    else
        echo "Failed to update sudoers file. Restoring backup."
        cp ${FILE}.bak $FILE
    fi
fi

#!/bin/bash
set -euo pipefail  # Exit on error, unset variables are errors, and catch pipeline errors.

# Determine the directory where this script is located.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Determine the parent directory of the script's directory.
PARENT_DIR="$( dirname "$SCRIPT_DIR" )"
# Set the target directory for cloning.
CLONE_DIR="${PARENT_DIR}/sourmash_alternate_implementations"

echo "Script is located in: $SCRIPT_DIR"
echo "Parent directory is: $PARENT_DIR"
echo "Target clone directory: $CLONE_DIR"

# Check if the directory already exists.
if [ -d "$CLONE_DIR" ]; then
    echo "Directory already exists. Updating repository..."
    cd "$CLONE_DIR" || { echo "Cannot cd to $CLONE_DIR"; exit 1; }
    git pull
else
    echo "Cloning repository..."
    git clone https://github.com/KoslickiLab/sourmash_alternate_implementations.git "$CLONE_DIR"
    if [ $? -ne 0 ]; then
        echo "Failed to clone repository."
        exit 1
    fi
    cd "$CLONE_DIR" || { echo "Cannot cd to $CLONE_DIR"; exit 1; }
fi

echo "Running make..."
make

#!/bin/bash
#
# AdaptiveScale Inc.
#

# Source the .env file
source .env

echo "#####################"
echo "#                   #"
echo "#  Starting Script  #"
echo "#                   #"
echo "#####################"

# Determine the OS and Architecture
OS=$(uname -s)
ARCH=$(uname -m)

# Set URL, ZIP_FILE, and EXTRACTION_DIR based on OS and ARCH
if [[ "$OS" == "Darwin" ]]; then
    if [[ "$ARCH" == "arm64" ]]; then
        echo "Running on macOS (ARM architecture)"
        export PATH=$PATH:rosetta/mac_aarch64/bin
    elif [[ "$ARCH" == "x86_64" ]]; then
        echo "Running on macOS (Intel architecture)"
        export PATH=$PATH:rosetta/mac_x64/bin
    else
        echo "Unknown architecture on macOS: $ARCH"
        exit 1
    fi
elif [[ "$OS" == "Linux" ]]; then
    echo "Running on Linux"
    if [[ "$ARCH" == "x86_64" ]]; then
        export PATH=$PATH:rosetta/linux_x64/bin
    elif [[ "$ARCH" == "arm64" ]]; then
        echo "Not supported Linux arm64"
    else
        echo "Unknown architecture on Linux: $ARCH"
        exit 1
    fi
else
    echo "Unsupported OS: $OS"
    exit 1
fi


# Set environment variables
export ROSETTA_DRIVERS=drivers/*
export EXTERNAL_TRANSLATION_FILE=translation/translation.csv

# Function to calculate total execution time
function calculate_execution_time {
    end_time=$(date +%s)
    execution_time=$((end_time - start_time))

    hours=$((execution_time / 3600))
    minutes=$(( (execution_time % 3600) / 60 ))
    seconds=$((execution_time % 60))

    printf "MySQL to Postgres changes migration script total execution time: %02d:%02d:%02d\n" $hours $minutes $seconds
}

# Start time
start_time=$(date +%s)

#Step 1: Schema Migration
echo "[DEBUG] ROSETTA_DRIVERS=$ROSETTA_DRIVERS"
echo "[DEBUG] PATH=$PATH"
echo "[DEBUG] EXTERNAL_TRANSLATION_FILE=$EXTERNAL_TRANSLATION_FILE"

echo "[DEBUG] Show rosetta version"
rosetta --version

echo "[DEBUG] Migrate schema: MySQL to Postgres"
rosetta extract -s mysql -t postgres
rosetta compile -s mysql -t postgres

echo "[DEBUG] Applying changes to Postgres"
rosetta apply -s postgres


calculate_execution_time

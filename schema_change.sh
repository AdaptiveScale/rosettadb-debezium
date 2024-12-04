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

# Set environment variables
export ROSETTA_DRIVERS=drivers/*
export PATH=$PATH:rosetta/bin
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

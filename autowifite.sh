#!/bin/bash

# autowifite.sh - An enhanced wrapper script for targeting specific SSIDs with wifite
# Usage: ./autowifite.sh <SSID> [additional wifite options]

# Display usage if no arguments provided
if [ $# -eq 0 ]; then
    echo "Usage: $(basename $0) <SSID> [additional wifite options]"
    echo "Example: $(basename $0) MyHomeNetwork -v --kill"
    exit 1
fi

# Store the SSID (first argument)
TARGET_SSID="$1"
shift  # Remove the first argument (SSID) from the arguments list

# Check if wifite is installed
if ! command -v wifite &> /dev/null; then
    echo "Error: wifite is not installed or not in PATH"
    echo "Please install wifite first"
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root"
    echo "Please run with sudo"
    exit 1
fi

# Get the wireless interface
INTERFACES=$(iw dev | grep Interface | awk '{print $2}')
if [ -z "$INTERFACES" ]; then
    echo "Error: No wireless interfaces found"
    exit 1
fi

# If there are multiple interfaces, use the first one
INTERFACE=$(echo "$INTERFACES" | head -n1)
echo "Using wireless interface: $INTERFACE"

echo "Starting wifite targeting SSID: $TARGET_SSID"
echo "Additional options: $@"

# Run wifite with the specified SSID and any additional arguments
wifite --essid "$TARGET_SSID" "$@"

# Return code
EXIT_CODE=$?

echo "wifite finished with exit code: $EXIT_CODE"

# Check if monitor mode interface exists and disable it
MONITOR_INTERFACE=$(iw dev | grep Interface | grep mon | awk '{print $2}')
if [ ! -z "$MONITOR_INTERFACE" ]; then
    echo "Disabling monitor mode on $MONITOR_INTERFACE..."
    airmon-ng stop "$MONITOR_INTERFACE" > /dev/null 2>&1
    echo "Monitor mode disabled."
fi

exit $EXIT_CODE
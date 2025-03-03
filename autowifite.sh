#!/bin/bash
# autowifite.sh - An enhanced wrapper script for targeting specific SSIDs with wifite
# Usage: ./autowifite.sh <SSID> [additional wifite options]

# Configuration
LOGFILE="/var/log/autowifite.log"
DATE=$(date "+%Y-%m-%d %H:%M:%S")

# Ensure log directory exists
LOG_DIR=$(dirname "$LOGFILE")
[ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"

# Log function
log() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOGFILE"
}

# Function to cleanup monitor mode and other tasks
cleanup() {
    log "Starting cleanup process..."
    
    # Find any monitor interfaces
    MONITOR_INTERFACES=$(iw dev | grep 'Interface' | grep 'mon' | awk '{print $2}')
    
    if [ -n "$MONITOR_INTERFACES" ]; then
        for MON_IFACE in $MONITOR_INTERFACES; do
            log "Disabling monitor mode on $MON_IFACE..."
            airmon-ng stop "$MON_IFACE" >> "$LOGFILE" 2>&1
            if [ $? -eq 0 ]; then
                log "Successfully disabled monitor mode on $MON_IFACE"
            else
                log "Warning: Failed to disable monitor mode on $MON_IFACE"
                # Alternative method if airmon-ng fails
                iw dev "$MON_IFACE" del >> "$LOGFILE" 2>&1 && log "Used iw to remove monitor interface"
            fi
        done
    else
        log "No monitor interfaces found to clean up"
    fi
    
    # Restart network services if they were killed
    if [[ " $KILLED_SERVICES " =~ " NetworkManager " ]]; then
        log "Restarting NetworkManager..."
        systemctl restart NetworkManager >> "$LOGFILE" 2>&1
    fi
    
    if [[ " $KILLED_SERVICES " =~ " wpa_supplicant " ]]; then
        log "Restarting wpa_supplicant..."
        systemctl restart wpa_supplicant >> "$LOGFILE" 2>&1
    fi
    
    log "Cleanup completed"
    
    # Only exit if called explicitly, not during normal script termination
    if [ "$1" = "force_exit" ]; then
        exit ${2:-1}
    fi
}

# Initialize variable for tracking killed services
KILLED_SERVICES=""

# Trap signals
trap 'log "Script interrupted. Performing cleanup..."; cleanup force_exit 130' INT TERM
trap '' PIPE

# Display banner
echo "====================================================="
echo "                   AUTOWIFITE                        "
echo "      Automated WiFi targeting with wifite           "
echo "====================================================="

# Display usage if no arguments provided
if [ $# -eq 0 ]; then
    echo "Usage: $(basename $0) <SSID> [additional wifite options]"
    echo "Example: $(basename $0) MyHomeNetwork -v --kill"
    exit 1
fi

# Store the SSID (first argument)
TARGET_SSID="$1"
shift  # Remove the first argument (SSID) from the arguments list

log "Script started - targeting SSID: $TARGET_SSID"
log "Additional wifite options: $@"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log "Error: This script must be run as root"
    echo "Please run with sudo or as root"
    exit 1
fi

# Check for required tools
for TOOL in wifite airmon-ng iw; do
    if ! command -v $TOOL &> /dev/null; then
        log "Error: $TOOL is not installed or not in PATH"
        echo "Please install $TOOL first"
        exit 1
    fi
done

# Get available wireless interfaces
INTERFACES=$(iw dev | grep Interface | grep -v mon | awk '{print $2}')
if [ -z "$INTERFACES" ]; then
    log "Error: No wireless interfaces found"
    echo "Error: No wireless interfaces found. Please ensure wireless adapter is connected."
    exit 1
fi

# If there are multiple interfaces, let user choose or use the first one
if [ $(echo "$INTERFACES" | wc -l) -gt 1 ]; then
    echo "Multiple wireless interfaces detected:"
    COUNT=1
    for IFACE in $INTERFACES; do
        # Show interface details like MAC address and chipset if possible
        MAC=$(ip link show $IFACE | grep -o 'link/ether [^ ]*' | cut -d' ' -f2)
        echo "$COUNT: $IFACE (MAC: $MAC)"
        ((COUNT++))
    done
    
    echo "Enter interface number [1-$((COUNT-1))], or press Enter to use the first one:"
    read CHOICE
    
    if [ -n "$CHOICE" ] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le $((COUNT-1)) ]; then
        INTERFACE=$(echo "$INTERFACES" | sed -n "${CHOICE}p")
    else
        INTERFACE=$(echo "$INTERFACES" | head -n1)
    fi
else
    INTERFACE=$INTERFACES
fi

log "Selected wireless interface: $INTERFACE"
echo "Using wireless interface: $INTERFACE"

# Check for --kill option and terminate conflicting processes
if [[ " $@ " =~ " --kill " ]] || [[ " $@ " =~ " -k " ]]; then
    log "Killing conflicting processes..."
    for PROCESS in NetworkManager wpa_supplicant dhclient dhcpcd; do
        PIDS=$(pgrep -f $PROCESS)
        if [ -n "$PIDS" ]; then
            log "Killing $PROCESS (PIDs: $PIDS)"
            for PID in $PIDS; do
                kill -9 $PID 2>/dev/null
                if [ $? -eq 0 ]; then
                    KILLED_SERVICES="$KILLED_SERVICES $PROCESS"
                fi
            done
        fi
    done
fi

# Enable monitor mode
log "Enabling monitor mode on $INTERFACE..."
MONITOR_RESULT=$(airmon-ng start $INTERFACE 2>&1)
log "Monitor mode result: $MONITOR_RESULT"

# Extract monitor interface name using more reliable methods
if echo "$MONITOR_RESULT" | grep -q "monitor mode enabled"; then
    # Try to extract from airmon-ng output first
    MONITOR_INTERFACE=$(echo "$MONITOR_RESULT" | grep "monitor mode enabled" | grep -o "mon[0-9]*\|$INTERFACE mon")
    
    # If that fails, check iw dev output
    if [ -z "$MONITOR_INTERFACE" ]; then
        MONITOR_INTERFACE=$(iw dev | grep -A 1 "Interface $INTERFACE" | grep -o "mon[0-9]*\|$INTERFACE mon")
    fi
    
    # If still not found, try to find any monitor interface
    if [ -z "$MONITOR_INTERFACE" ]; then
        MONITOR_INTERFACE=$(iw dev | grep Interface | grep mon | awk '{print $2}' | head -n 1)
    fi
else
    # If monitor mode wasn't enabled via airmon-ng output, check if interface exists in monitor mode
    MONITOR_INTERFACE=$(iw dev | grep Interface | grep mon | awk '{print $2}' | head -n 1)
fi

# Validate monitor interface
if [ -z "$MONITOR_INTERFACE" ]; then
    log "Error: Failed to enable monitor mode"
    echo "Failed to enable monitor mode. Trying alternative method..."
    
    # Try alternative method using iw
    iw dev $INTERFACE set type monitor
    if [ $? -eq 0 ]; then
        log "Successfully enabled monitor mode using iw"
        MONITOR_INTERFACE=$INTERFACE
    else
        log "Error: All methods to enable monitor mode failed"
        echo "Could not enable monitor mode. Exiting."
        cleanup force_exit 1
    fi
fi

log "Monitor interface: $MONITOR_INTERFACE"
echo "Monitor mode enabled on interface: $MONITOR_INTERFACE"

# Run wifite with the specified SSID and any additional arguments
log "Starting wifite targeting SSID: $TARGET_SSID with interface $MONITOR_INTERFACE"
echo "Starting wifite..."

# Add explicit interface parameter if not in the additional arguments
if [[ ! " $@ " =~ " -i " ]] && [[ ! " $@ " =~ " --interface " ]]; then
    INTERFACE_PARAM="-i $MONITOR_INTERFACE"
else
    INTERFACE_PARAM=""
fi

wifite --essid "$TARGET_SSID" $INTERFACE_PARAM "$@" 2>&1 | tee -a "$LOGFILE"
EXIT_CODE=${PIPESTATUS[0]}

log "wifite finished with exit code: $EXIT_CODE"

# Perform cleanup
cleanup

log "Script completed successfully"
exit $EXIT_CODE

#!/bin/bash

# Uninstallation script for Face Recognition Server
# This script removes the service from system boot

SERVICE_NAME="face-recognition-server"
SYSTEMD_DIR="/etc/systemd/system"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_message "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

log_message "Uninstalling Face Recognition Server service..."

# Stop the service if it's running
if systemctl is-active --quiet "$SERVICE_NAME"; then
    systemctl stop "$SERVICE_NAME"
    log_message "Stopped $SERVICE_NAME service"
fi

# Disable the service
if systemctl is-enabled --quiet "$SERVICE_NAME"; then
    systemctl disable "$SERVICE_NAME"
    log_message "Disabled $SERVICE_NAME from starting on boot"
fi

# Remove service file
if [ -f "$SYSTEMD_DIR/${SERVICE_NAME}.service" ]; then
    rm "$SYSTEMD_DIR/${SERVICE_NAME}.service"
    log_message "Removed service file: $SYSTEMD_DIR/${SERVICE_NAME}.service"
fi

# Reload systemd daemon
systemctl daemon-reload
log_message "Reloaded systemd daemon"

log_message "✅ Face Recognition Server service uninstalled successfully"
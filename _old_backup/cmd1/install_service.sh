#!/bin/bash

# Installation script for Face Recognition Server
# This script sets up the service to start automatically on system boot

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

SERVICE_NAME="face-recognition-server"
SERVICE_FILE="$SCRIPT_DIR/${SERVICE_NAME}.service"
SYSTEMD_DIR="/etc/systemd/system"
SCRIPT_FILE="$SCRIPT_DIR/face_recognition_server.sh"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_message "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

log_message "Installing Face Recognition Server as system service..."

# Make the script executable
chmod +x "$SCRIPT_FILE"
log_message "Made script executable: $SCRIPT_FILE"

# Copy service file to systemd directory
if [ -f "$SERVICE_FILE" ]; then
    cp "$SERVICE_FILE" "$SYSTEMD_DIR/"
    log_message "Copied service file to: $SYSTEMD_DIR/${SERVICE_NAME}.service"
else
    log_message "ERROR: Service file not found: $SERVICE_FILE"
    exit 1
fi

# Reload systemd daemon
systemctl daemon-reload
log_message "Reloaded systemd daemon"

# Enable the service to start on boot
systemctl enable "$SERVICE_NAME"
log_message "Enabled $SERVICE_NAME to start on boot"

# Start the service
systemctl start "$SERVICE_NAME"
log_message "Started $SERVICE_NAME service"

# Check service status
sleep 2
if systemctl is-active --quiet "$SERVICE_NAME"; then
    log_message "✅ Service is running successfully"
    systemctl status "$SERVICE_NAME" --no-pager -l
else
    log_message "❌ Service failed to start"
    log_message "Check logs with: journalctl -u $SERVICE_NAME -f"
    systemctl status "$SERVICE_NAME" --no-pager -l
fi

log_message "Installation complete!"
log_message ""
log_message "Service management commands:"
log_message "  Start:   sudo systemctl start $SERVICE_NAME"
log_message "  Stop:    sudo systemctl stop $SERVICE_NAME"
log_message "  Restart: sudo systemctl restart $SERVICE_NAME"
log_message "  Status:  sudo systemctl status $SERVICE_NAME"
log_message "  Logs:    sudo journalctl -u $SERVICE_NAME -f"
log_message "  Disable: sudo systemctl disable $SERVICE_NAME"
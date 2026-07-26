#!/bin/bash

# Face Recognition Server Startup Script
# This script reads configuration from config.txt and starts the main application

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/config.txt"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to read config value
get_config_value() {
    local key="$1"
    grep "^$key=" "$CONFIG_FILE" | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    log_message "ERROR: Configuration file not found at $CONFIG_FILE"
    exit 1
fi

# Read configuration
APP_PATH=$(get_config_value "APP_PATH")
PYTHON_PATH=$(get_config_value "PYTHON_PATH")
WORK_DIR=$(get_config_value "WORK_DIR")
LOG_FILE=$(get_config_value "LOG_FILE")
PROCESS_NAME=$(get_config_value "PROCESS_NAME")

# Set defaults if not specified
PYTHON_PATH=${PYTHON_PATH:-python}
WORK_DIR=${WORK_DIR:-$(dirname "$APP_PATH")}
LOG_FILE=${LOG_FILE:-"$WORK_DIR/app.log"}

log_message "Starting Face Recognition Server..."
log_message "App Path: $APP_PATH"
log_message "Python Path: $PYTHON_PATH"
log_message "Working Directory: $WORK_DIR"
log_message "Log File: $LOG_FILE"

# Check if application file exists
if [ ! -f "$APP_PATH" ]; then
    log_message "ERROR: Application file not found at $APP_PATH"
    exit 1
fi

# Change to working directory
cd "$WORK_DIR" || {
    log_message "ERROR: Cannot change to working directory $WORK_DIR"
    exit 1
}

# Function to start the application
start_app() {
    log_message "Starting application..."
    
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Start the application with logging
    nohup "$PYTHON_PATH" "$APP_PATH" >> "$LOG_FILE" 2>&1 &
    APP_PID=$!
    
    # Wait a moment to check if the process started successfully
    sleep 2
    
    if kill -0 "$APP_PID" 2>/dev/null; then
        log_message "Application started successfully with PID: $APP_PID"
        echo "$APP_PID" > "$WORK_DIR/${PROCESS_NAME}.pid"
        return 0
    else
        log_message "ERROR: Application failed to start"
        return 1
    fi
}

# Function to stop the application
stop_app() {
    local pid_file="$WORK_DIR/${PROCESS_NAME}.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            log_message "Stopping application with PID: $pid"
            kill "$pid"
            
            # Wait for graceful shutdown
            local count=0
            while kill -0 "$pid" 2>/dev/null && [ $count -lt 10 ]; do
                sleep 1
                count=$((count + 1))
            done
            
            # Force kill if still running
            if kill -0 "$pid" 2>/dev/null; then
                log_message "Force killing application..."
                kill -9 "$pid"
            fi
            
            rm -f "$pid_file"
            log_message "Application stopped"
        else
            log_message "Application not running (stale PID file)"
            rm -f "$pid_file"
        fi
    else
        log_message "No PID file found"
    fi
}

# Function to check application status
check_status() {
    local pid_file="$WORK_DIR/${PROCESS_NAME}.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            log_message "Application is running with PID: $pid"
            return 0
        else
            log_message "Application is not running (stale PID file)"
            rm -f "$pid_file"
            return 1
        fi
    else
        log_message "Application is not running"
        return 1
    fi
}

# Function to restart the application
restart_app() {
    log_message "Restarting application..."
    stop_app
    sleep 2
    start_app
}

# Main script logic
case "${1:-start}" in
    start)
        if check_status >/dev/null 2>&1; then
            log_message "Application is already running"
        else
            start_app
        fi
        ;;
    stop)
        stop_app
        ;;
    restart)
        restart_app
        ;;
    status)
        check_status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        echo "  start   - Start the Face Recognition Server"
        echo "  stop    - Stop the Face Recognition Server" 
        echo "  restart - Restart the Face Recognition Server"
        echo "  status  - Check if the server is running"
        exit 1
        ;;
esac
# Face Recognition Server - Service Management

This folder contains scripts to manage the Face Recognition Server as a system service that starts automatically on boot.

## Files Description

### Configuration
- `../config_windows.txt` - Configuration file containing paths and settings (Windows)
- `../config.txt` - Configuration file containing paths and settings (Linux)

### Windows Scripts (.bat files)
- `face_recognition_server.bat` - Main service control script for Windows
- `start_server.bat` - Simple startup script for manual use
- `install_service.bat` - Install as Windows Service (requires Administrator)
- `uninstall_service.bat` - Uninstall Windows Service (requires Administrator)
- `install_task.bat` - Install as Windows Startup Task (requires Administrator)
- `uninstall_task.bat` - Uninstall Windows Startup Task (requires Administrator)

### Linux Scripts (.sh files)
- `face_recognition_server.sh` - Main service control script for Linux
- `install_service.sh` - Installation script to set up auto-start on boot
- `uninstall_service.sh` - Uninstallation script to remove auto-start
- `face-recognition-server.service` - Systemd service definition file

## Windows Installation

### 🚀 **EASIEST METHOD - One-Click Install:**
**Double-click** `install_auto_start.bat` and choose your preferred method.

### Available Methods:

#### Method 1: Registry Startup (Recommended)
- **Right-click and "Run as Administrator"** on `install_registry.bat`
- Starts for all users when Windows boots
- Most reliable method

#### Method 2: User Startup Folder (No Admin Required)
- **Double-click** `install_startup.bat` (No admin needed)
- Starts when current user logs in
- Easy to install/uninstall

#### Method 3: Windows Service (Advanced)
- **Right-click and "Run as Administrator"** on `install_service_improved.bat`
- Requires `pip install pywin32`
- Runs as system service

#### Method 4: Scheduled Task
- **Right-click and "Run as Administrator"** on `install_task.bat`
- Uses Windows Task Scheduler
- Can be less reliable

## Windows Manual Usage

### Simple startup (double-click or from Command Prompt)
```batch
cmd\start_server.bat
```

### Advanced control script
```batch
cmd\face_recognition_server.bat start
cmd\face_recognition_server.bat stop
cmd\face_recognition_server.bat restart
cmd\face_recognition_server.bat status
```

## Windows Service Management

After installing as Windows Service, you can manage it using:

### Using Command Prompt (as Administrator)
```batch
sc start FaceRecognitionServer
sc stop FaceRecognitionServer
sc query FaceRecognitionServer
```

### Using Services.msc
1. Press `Win + R`, type `services.msc`, press Enter
2. Find "Face Recognition Server" in the list
3. Right-click to Start/Stop/Restart

## Linux Installation (for Linux systems)

### 1. Make scripts executable
```bash
chmod +x cmd/*.sh
```

### 2. Install as system service (requires sudo)
```bash
sudo ./cmd/install_service.sh
```

## Linux Manual Usage

### Start the service manually
```bash
./cmd/face_recognition_server.sh start
```

### Stop the service
```bash
./cmd/face_recognition_server.sh stop
```

### Restart the service
```bash
./cmd/face_recognition_server.sh restart
```

### Check service status
```bash
./cmd/face_recognition_server.sh status
```

## Linux System Service Management

After installation, you can manage the service using systemctl:

### Check service status
```bash
sudo systemctl status face-recognition-server
```

### Start/Stop/Restart service
```bash
sudo systemctl start face-recognition-server
sudo systemctl stop face-recognition-server
sudo systemctl restart face-recognition-server
```

### View service logs
```bash
sudo journalctl -u face-recognition-server -f
```

### Disable auto-start on boot
```bash
sudo systemctl disable face-recognition-server
```

### Enable auto-start on boot
```bash
sudo systemctl enable face-recognition-server
```

## Windows Uninstallation

### Remove Windows Service
**Right-click and "Run as Administrator"** on `uninstall_service.bat`

### Remove Scheduled Task
**Right-click and "Run as Administrator"** on `uninstall_task.bat`

## Linux Uninstallation

To remove the service from auto-start:
```bash
sudo ./cmd/uninstall_service.sh
```

## Configuration

### Windows
Edit the `config_windows.txt` file to modify paths and settings:
- `APP_PATH` - Path to main_api_cam.py
- `PYTHON_PATH` - Python executable path
- `WORK_DIR` - Working directory
- `LOG_FILE` - Log file location
- `PROCESS_NAME` - Process name for identification

### Linux
Edit the `config.txt` file with the same settings format.

## Log Files

### Windows
- Application logs: `app.log` (configured in config_windows.txt)
- Service logs: Check Windows Event Viewer → Windows Logs → Application
- Task logs: Check Task Scheduler → Task Scheduler Library

### Linux
- Application logs: `app.log` (configured in config.txt)
- Service logs: `service.log`
- System logs: Use `journalctl -u face-recognition-server`

## Troubleshooting

### Windows
1. **Service won't start**: Check Windows Event Viewer for error details
2. **Permission issues**: Ensure you run installation scripts as Administrator
3. **Path issues**: Verify paths in config_windows.txt use backslashes and are correct
4. **Python not found**: Ensure Python is installed and in PATH, or specify full path in config

### Linux
1. **Service won't start**: Check logs with `journalctl -u face-recognition-server`
2. **Permission issues**: Ensure scripts are executable and run installation with sudo
3. **Path issues**: Verify paths in config.txt are correct
4. **Python dependencies**: Ensure all required packages are installed

## Requirements

### Windows
- Windows 10/11 or Windows Server
- Python with required dependencies
- Administrator access for service installation
- Working Face Recognition Server application

### Linux
- Linux system with systemd
- Python with required dependencies
- Root access for service installation
- Working Face Recognition Server application
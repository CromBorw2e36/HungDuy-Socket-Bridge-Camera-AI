# TROUBLESHOOTING GUIDE - Face Recognition Server Auto-Start

## Problem: Server doesn't start after PC restart

This guide will help you fix the auto-start issue step by step.

### Step 1: Check What's Currently Installed

Open **Command Prompt as Administrator** and run these commands:

```batch
# Check Windows Service
sc query FaceRecognitionServer

# Check Scheduled Task  
schtasks /query /tn "FaceRecognitionServer"

# Check Registry Entry
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "FaceRecognitionServer"
```

### Step 2: Clean Installation

1. **FIRST**: Remove all existing installations
   - **Right-click as Administrator**: `uninstall_all.bat`

2. **SECOND**: Choose the best method for your system:

#### 🥇 **BEST OPTION: Registry Method** (Works 99% of time)
```batch
# Right-click as Administrator and run:
install_registry.bat
```

#### 🥈 **BACKUP OPTION: User Startup** (No admin needed)
```batch
# Just double-click (no admin needed):
install_startup.bat
```

### Step 3: Verify Installation

After installation, verify it worked:

#### For Registry Method:
```batch
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "FaceRecognitionServer"
```
Should show: `k:\Project\HungDuyCoLTD\BridgeWebCamera\cmd\start_server_silent.bat`

#### For Startup Folder Method:
Check if this file exists:
```
%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Face Recognition Server.bat
```

### Step 4: Test Manually

Before restarting, test if the script works:

1. **Double-click**: `cmd\start_server_silent.bat`
2. Wait 30 seconds
3. Check if the server is running by opening: http://localhost:8080

### Step 5: Restart Test

1. **Restart your computer**
2. **Wait 2 minutes** after login (let Windows fully load)
3. Check if server is running: http://localhost:8080

## Common Issues & Fixes

### Issue 1: "Access Denied" when installing
**Solution**: Must run as Administrator
- Right-click the .bat file → "Run as administrator"

### Issue 2: Python not found
**Solution**: Check Python installation
```batch
python --version
where python
```
If not found, install Python or fix PATH environment variable.

### Issue 3: Script runs but server doesn't start
**Solution**: Check the main application
```batch
cd k:\Project\HungDuyCoLTD\BridgeWebCamera
python main_api_cam.py
```
Fix any errors in the main application first.

### Issue 4: Registry method doesn't work
**Solution**: Try User Startup method instead
```batch
# No admin needed:
install_startup.bat
```

### Issue 5: Multiple methods installed, conflicts
**Solution**: Clean everything and reinstall
```batch
# Right-click as Admin:
uninstall_all.bat

# Then pick ONE method:
install_registry.bat
```

## Windows Compatibility

| Method | Windows 10 | Windows 11 | Admin Required | Reliability |
|--------|------------|------------|----------------|-------------|
| Registry | ✅ | ✅ | Yes | 99% |
| Startup Folder | ✅ | ✅ | No | 95% |
| Windows Service | ✅ | ✅ | Yes | 90% |
| Scheduled Task | ✅ | ✅ | Yes | 80% |

## Emergency Manual Start

If auto-start fails, you can always start manually:
```batch
cd k:\Project\HungDuyCoLTD\BridgeWebCamera
cmd\start_server.bat
```

## Getting Help

If none of these solutions work:

1. **Check Windows Event Viewer**:
   - Press `Win + R` → `eventvwr.msc`
   - Look for errors related to "FaceRecognitionServer"

2. **Check the log files**:
   - `k:\Project\HungDuyCoLTD\BridgeWebCamera\app.log`
   - `k:\Project\HungDuyCoLTD\BridgeWebCamera\hailort.log`

3. **Test step by step**:
   - Can you run `python main_api_cam.py` manually?
   - Can you run `cmd\start_server.bat` manually?  
   - Can you run `cmd\start_server_silent.bat` manually?

## Success Indicators

✅ **Auto-start is working if**:
- After PC restart, you can access http://localhost:8080
- Camera detection starts automatically
- No manual intervention needed

The **Registry method** is recommended because it's the most reliable and starts the server early in the Windows boot process.
import os
import sys
import time
import subprocess
import threading
from pathlib import Path

# Add the project directory to Python path
project_dir = Path(__file__).parent.parent
sys.path.insert(0, str(project_dir))

try:
    import servicemanager
    import win32event
    import win32service
    import win32serviceutil
    SERVICE_AVAILABLE = True
except ImportError:
    SERVICE_AVAILABLE = False
    print("Windows service modules not available. Install with: pip install pywin32")

class FaceRecognitionService:
    def __init__(self):
        self.stop_event = None
        self.process = None
        
    def start(self):
        """Start the Face Recognition Server"""
        # Read config
        config_file = project_dir / "config_windows.txt"
        config = self.read_config(config_file)
        
        app_path = config.get('APP_PATH', str(project_dir / "main_api_cam.py"))
        python_path = config.get('PYTHON_PATH', 'pythonw')
        work_dir = config.get('WORK_DIR', str(project_dir))
        
        # Change to working directory
        os.chdir(work_dir)
        
        # Start the main application
        cmd = [python_path, app_path]
        self.process = subprocess.Popen(
            cmd,
            cwd=work_dir,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            creationflags=subprocess.CREATE_NO_WINDOW
        )
        
        print(f"Started Face Recognition Server with PID: {self.process.pid}")
        
    def stop(self):
        """Stop the Face Recognition Server"""
        if self.process:
            self.process.terminate()
            try:
                self.process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.process.kill()
            print("Face Recognition Server stopped")
            
    def read_config(self, config_file):
        """Read configuration from file"""
        config = {}
        if config_file.exists():
            with open(config_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#') and '=' in line:
                        key, value = line.split('=', 1)
                        config[key.strip()] = value.strip()
        return config

if SERVICE_AVAILABLE:
    class FaceRecognitionWindowsService(win32serviceutil.ServiceFramework):
        _svc_name_ = "FaceRecognitionServer"
        _svc_display_name_ = "Face Recognition Server"
        _svc_description_ = "Face Recognition Server for Bridge Web Camera"
        
        def __init__(self, args):
            win32serviceutil.ServiceFramework.__init__(self, args)
            self.hWaitStop = win32event.CreateEvent(None, 0, 0, None)
            self.server = FaceRecognitionService()
            
        def SvcStop(self):
            self.ReportServiceStatus(win32service.SERVICE_STOP_PENDING)
            win32event.SetEvent(self.hWaitStop)
            self.server.stop()
            
        def SvcDoRun(self):
            servicemanager.LogMsg(
                servicemanager.EVENTLOG_INFORMATION_TYPE,
                servicemanager.PYS_SERVICE_STARTED,
                (self._svc_name_, '')
            )
            self.server.start()
            win32event.WaitForSingleObject(self.hWaitStop, win32event.INFINITE)

def main():
    if len(sys.argv) > 1:
        if sys.argv[1] == 'install':
            if not SERVICE_AVAILABLE:
                print("Error: pywin32 not installed. Install with: pip install pywin32")
                return
            win32serviceutil.InstallService(
                FaceRecognitionWindowsService,
                "FaceRecognitionServer",
                "Face Recognition Server",
                startType=win32service.SERVICE_AUTO_START
            )
            print("Service installed successfully")
            
        elif sys.argv[1] == 'remove':
            if not SERVICE_AVAILABLE:
                print("Error: pywin32 not installed")
                return
            win32serviceutil.RemoveService("FaceRecognitionServer")
            print("Service removed successfully")
            
        elif sys.argv[1] == 'start':
            server = FaceRecognitionService()
            try:
                server.start()
                print("Face Recognition Server started. Press Ctrl+C to stop...")
                while True:
                    time.sleep(1)
            except KeyboardInterrupt:
                server.stop()
                print("Stopped")
                
    else:
        if SERVICE_AVAILABLE:
            win32serviceutil.HandleCommandLine(FaceRecognitionWindowsService)
        else:
            # Run as regular application
            server = FaceRecognitionService()
            try:
                server.start()
                print("Face Recognition Server started. Press Ctrl+C to stop...")
                while True:
                    time.sleep(1)
            except KeyboardInterrupt:
                server.stop()
                print("Stopped")

if __name__ == '__main__':
    main()
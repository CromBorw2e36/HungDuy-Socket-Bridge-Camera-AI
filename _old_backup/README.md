# Face Recognition Socket Server

This system provides real-time face recognition with socket server capabilities for web and desktop clients.

## Features

- Real-time face detection and recognition using webcam
- Socket server for TCP clients (port 8080)
- WebSocket server for web clients (port 8765)
- Sends live video feed with recognition data (UUID, name, confidence)
- HTML web client for browser-based viewing
- Python test client for desktop applications

## Files Overview

### Core Files
- `main_api_cam.py` - Main application with face recognition and socket servers
- `socket_server.py` - TCP socket server implementation
- `websocket_server.py` - WebSocket server for web clients
- `hailo_inference.py` - Hailo AI inference engine
- `Utils.py` - Utility functions for image processing

### Client Files
- `client.html` - Web browser client
- `test_client.py` - Python desktop client for testing

### Model Files
- `scrfd_2.5g.hef` - Face detection model
- `arcface_r50.hef` - Face recognition model

### Data
- `employees_data/` - Employee face data in JSON format

## Installation

1. Install required Python packages:
```bash
pip install opencv-python numpy pandas pyodbc faiss-cpu websockets asyncio
```

2. Ensure you have the Hailo inference engine and model files available.

## Usage

### Starting the Server

1. Run the main application:
```bash
python main_api_cam.py
```

This will start:
- Face recognition from webcam
- TCP socket server on port 8080
- WebSocket server on port 8765

### Connecting Clients

#### Web Client (Browser)
1. Open `client.html` in a web browser
2. Click "Connect" button
3. The client will connect to `ws://localhost:8765`
4. View live video feed with recognition overlays

#### Python Client (Desktop)
1. Run the test client:
```bash
python test_client.py
```
2. The client will connect to `localhost:8080`
3. View video feed in OpenCV window
4. Press 'q' to quit

### Data Format

The system sends recognition data in the following formats:

#### TCP Socket (port 8080)
```
UUID:{uuid}|NAME:{name}|CONFIDENCE:{confidence}|IMAGE:{base64_image_data}
```

#### WebSocket (port 8765)
```json
{
  "type": "frame",
  "timestamp": 1234567890.123,
  "image": "base64_encoded_jpeg_data",
  "recognition": {
    "uuid": "employee_uuid",
    "name": "employee_name", 
    "confidence": 0.85
  }
}
```

## Configuration

### Server Settings
- TCP Socket Server: `0.0.0.0:8080`
- WebSocket Server: `0.0.0.0:8765`
- Webcam Resolution: 640x640
- Frame Rate: 30 FPS

### Recognition Settings
- Detection Model: SCRFD 2.5G
- Recognition Model: ArcFace R50
- Recognition Threshold: 0.6
- Top K Matches: 3

## Console Output

When a face is successfully recognized, the console will show:
```
Detection SUCCESS - UUID: {uuid}, Name: {name}, Confidence: {confidence}
```

## Network Access

The servers bind to `0.0.0.0`, allowing connections from:
- Local machine: `localhost` or `127.0.0.1`
- Network clients: Use the machine's IP address

Example for network access:
- TCP: `192.168.1.100:8080`
- WebSocket: `ws://192.168.1.100:8765`

## Troubleshooting

1. **Camera not detected**: Ensure webcam is connected and not used by other applications
2. **Connection refused**: Check if ports 8080 and 8765 are available
3. **No face recognition**: Verify model files exist and employee data is loaded
4. **High CPU usage**: Reduce frame rate or image quality in the code

## Adding New Employees

Employee data is stored in `employees_data/` as JSON files. The system automatically loads existing employee data on startup and processes new entries from the database.

Each employee JSON file contains:
```json
{
  "uid": "employee_uuid",
  "name": "Employee Name",
  "faces": [
    {
      "url": "image_path",
      "embedding": [0.1, 0.2, ...]
    }
  ]
}
```
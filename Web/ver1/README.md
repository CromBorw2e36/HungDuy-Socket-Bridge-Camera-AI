# Face Recognition Web Service

A comprehensive JavaScript service for connecting to the face recognition WebSocket server, streaming images, and logging face detection events.

## Files Overview

- **`main.js`** - Core service classes (`FaceRecognitionService` and `FaceRecognitionUI`)
- **`index.html`** - Dashboard interface for the service
- **`test.js`** - Test scripts and usage examples
- **`client.html`** - Alternative simple client interface

## Service Features

### FaceRecognitionService Class

#### Core Functionality
- **WebSocket Connection**: Connects to face recognition server
- **Image Streaming**: Receives and processes live video frames
- **Face Detection Logging**: Stores detection events with metadata
- **Auto-reconnection**: Handles connection failures gracefully
- **Event Callbacks**: Customizable event handling

#### Key Methods

```javascript
// Initialize service
const service = new FaceRecognitionService();

// Configure connection
service.configure({
    host: 'localhost',
    port: 8765,
    protocol: 'ws'
});

// Set event callbacks
service.setCallbacks({
    onImageReceived: (imageUrl, timestamp) => { /* handle image */ },
    onFaceDetected: (logEntry) => { /* handle detection */ },
    onConnectionChanged: (connected) => { /* handle connection */ },
    onError: (error) => { /* handle error */ }
});

// Connect to server
await service.connect();

// Get face detection log
const detections = service.getLogFace(10); // Get last 10 detections
const allDetections = service.getLogFace(); // Get all detections

// Search and filter
const personDetections = service.getLogFaceByUuid('uuid-here');
const nameSearch = service.getLogFaceByName('John');
const todayDetections = service.getLogFaceByDateRange(startDate, endDate);

// Export data
const jsonData = service.exportLogFace();

// Get statistics
const stats = service.getStatistics();
```

### FaceRecognitionUI Class

Provides a complete UI controller that works with the service to display:
- Live video stream
- Current face detection
- Detection history
- Connection status
- Statistics

## Data Formats

### Face Detection Log Entry
```javascript
{
    id: "unique-log-id",
    image: "base64-image-data",
    name: "Person Name",
    uuid: "person-uuid",
    confidence: 0.85,
    timestamp: 1234567890123,
    date: Date object
}
```

### Service Statistics
```javascript
{
    isConnected: true,
    totalDetections: 150,
    uniquePersons: 25,
    reconnectAttempts: 0,
    lastDetection: Date object
}
```

### WebSocket Message Formats

#### JSON Format (Primary)
```javascript
{
    type: "frame",
    timestamp: 1234567890.123,
    image: "base64-jpeg-data",
    recognition: {
        uuid: "person-uuid",
        name: "Person Name",
        confidence: 0.85
    }
}
```

#### Simple String Format (Fallback)
```
UUID:person-uuid|NAME:Person Name|CONFIDENCE:0.85|IMAGE:base64-data
```

## Usage Examples

### Basic Setup
```javascript
// Create and configure service
const service = new FaceRecognitionService();
service.configure({ host: 'localhost', port: 8765 });

// Set up callbacks
service.setCallbacks({
    onFaceDetected: (detection) => {
        console.log(`Detected: ${detection.name} (${detection.confidence})`);
    }
});

// Connect
await service.connect();
```

### Real-time Monitoring
```javascript
let detectionCount = 0;

service.setCallbacks({
    onFaceDetected: (logEntry) => {
        detectionCount++;
        console.log(`Detection #${detectionCount}: ${logEntry.name}`);
        
        // High confidence alert
        if (logEntry.confidence > 0.9) {
            alert(`High confidence detection: ${logEntry.name}`);
        }
    }
});
```

### Data Export
```javascript
// Export all detections as JSON file
function exportDetections() {
    const jsonData = service.exportLogFace();
    const blob = new Blob([jsonData], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    
    const a = document.createElement('a');
    a.href = url;
    a.download = 'face-detections.json';
    a.click();
    
    URL.revokeObjectURL(url);
}
```

### Search and Filter
```javascript
// Get detections from last hour
const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
const recentDetections = service.getLogFaceByDateRange(oneHourAgo, new Date());

// Find specific person
const johnDetections = service.getLogFaceByName('John');

// Get unique persons detected today
const today = new Date();
today.setHours(0, 0, 0, 0);
const todayDetections = service.getLogFaceByDateRange(today, new Date());
const uniqueToday = [...new Set(todayDetections.map(d => d.uuid))];
```

## Dashboard Interface

The `index.html` provides a complete dashboard with:

### Features
- **Live Video Stream**: Real-time display of camera feed
- **Connection Controls**: Connect/disconnect buttons with status indicator
- **Current Detection**: Shows latest face detection with details
- **Statistics Panel**: Displays connection status and detection counts
- **Detection History**: Grid view of recent detections
- **Export/Clear Functions**: Data management tools

### Dashboard Layout
- Responsive grid layout
- Modern glassmorphism design
- Real-time updates
- Mobile-friendly responsive design

## Integration with Python Server

The service is designed to work with the Python face recognition server:

1. **Start Python Server**:
   ```bash
   python main_api_cam.py
   ```

2. **Open Web Interface**:
   ```bash
   # Serve the web files (example with Python)
   cd Web
   python -m http.server 8000
   ```

3. **Access Dashboard**:
   Open `http://localhost:8000/index.html` in browser

## Configuration Options

### Service Configuration
```javascript
service.configure({
    host: 'localhost',        // WebSocket server host
    port: 8765,              // WebSocket server port
    protocol: 'ws',          // Protocol (ws or wss)
    maxReconnectAttempts: 5, // Max auto-reconnect attempts
    reconnectDelay: 3000     // Delay between reconnect attempts (ms)
});
```

### UI Configuration
The UI automatically adapts to the service configuration and provides:
- Connection status indicators
- Real-time statistics
- Responsive layout
- Error handling and user feedback

## Browser Compatibility

- **Modern Browsers**: Chrome 76+, Firefox 72+, Safari 13+, Edge 79+
- **WebSocket Support**: Required
- **ES6+ Features**: Classes, async/await, destructuring
- **Responsive Design**: Mobile and desktop compatible

## Error Handling

The service includes comprehensive error handling:
- Connection failures with auto-reconnect
- Message parsing errors
- WebSocket errors
- UI error display with user feedback

## Performance Considerations

- **Image Compression**: JPEG quality set to 70% for optimal balance
- **Log Management**: Automatic log size limiting (default 100 entries)
- **Memory Management**: Proper cleanup and resource release
- **Frame Rate**: ~30 FPS with automatic throttling

## Development and Testing

Use the test functions in `test.js`:
```javascript
// Test service functionality
const service = testFaceRecognitionService();

// Demonstrate filtering
demonstrateLogFiltering(service);

// Set up monitoring
setupRealTimeMonitoring(service);

// Export data
exportDetectionData(service);
```

## Security Considerations

- **CORS**: Configure server CORS policies appropriately
- **WSS**: Use secure WebSocket (wss://) for production
- **Data Privacy**: Face images stored temporarily in memory only
- **Access Control**: Implement authentication if needed
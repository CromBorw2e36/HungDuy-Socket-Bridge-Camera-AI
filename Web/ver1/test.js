/**
 * Test script for Face Recognition Service
 * This file demonstrates how to use the FaceRecognitionService programmatically
 */

// Example of using the service programmatically
function testFaceRecognitionService() {
    console.log('Testing Face Recognition Service...');
    
    // Create service instance
    const service = new FaceRecognitionService();
    
    // Configure service
    service.configure({
        host: 'localhost',
        port: 8765,
        protocol: 'ws'
    });
    
    // Set up event callbacks
    service.setCallbacks({
        onImageReceived: (imageUrl, timestamp) => {
            console.log('Image received at:', new Date(timestamp));
            // You can process the image here
        },
        
        onFaceDetected: (logEntry) => {
            console.log('Face detected:', {
                name: logEntry.name,
                uuid: logEntry.uuid,
                confidence: logEntry.confidence,
                timestamp: logEntry.date
            });
            
            // Example: Send detection to external API
            sendDetectionToAPI(logEntry);
        },
        
        onConnectionChanged: (connected) => {
            console.log('Connection status changed:', connected ? 'Connected' : 'Disconnected');
        },
        
        onError: (error) => {
            console.error('Service error:', error);
        }
    });
    
    // Connect to service
    service.connect()
        .then(() => {
            console.log('Successfully connected to face recognition service');
            
            // Example: Get log after some time
            setTimeout(() => {
                const recentDetections = service.getLogFace(5);
                console.log('Recent detections:', recentDetections);
                
                const statistics = service.getStatistics();
                console.log('Service statistics:', statistics);
            }, 10000); // Wait 10 seconds
        })
        .catch(error => {
            console.error('Failed to connect:', error);
        });
    
    return service;
}

// Example function to send detection data to external API
async function sendDetectionToAPI(logEntry) {
    try {
        const response = await fetch('/api/face-detections', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                uuid: logEntry.uuid,
                name: logEntry.name,
                confidence: logEntry.confidence,
                timestamp: logEntry.timestamp,
                // Note: Don't send image data to API unless necessary (large payload)
            })
        });
        
        if (response.ok) {
            console.log('Detection sent to API successfully');
        } else {
            console.error('Failed to send detection to API:', response.statusText);
        }
    } catch (error) {
        console.error('Error sending detection to API:', error);
    }
}

// Example of filtering and searching face logs
function demonstrateLogFiltering(service) {
    console.log('Demonstrating log filtering...');
    
    // Get all detections
    const allDetections = service.getLogFace();
    console.log('Total detections:', allDetections.length);
    
    // Get detections by specific UUID
    const specificPersonDetections = service.getLogFaceByUuid('some-uuid-here');
    console.log('Detections for specific person:', specificPersonDetections.length);
    
    // Get detections by name (partial match)
    const nameSearchResults = service.getLogFaceByName('John');
    console.log('Detections matching "John":', nameSearchResults.length);
    
    // Get detections from today
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);
    
    const todayDetections = service.getLogFaceByDateRange(today, tomorrow);
    console.log('Detections from today:', todayDetections.length);
    
    // Get statistics
    const stats = service.getStatistics();
    console.log('Service statistics:', stats);
}

// Example of exporting data
function exportDetectionData(service) {
    // Export as JSON
    const jsonData = service.exportLogFace();
    console.log('Exported JSON data length:', jsonData.length);
    
    // Create and download file
    const blob = new Blob([jsonData], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    
    const a = document.createElement('a');
    a.href = url;
    a.download = `face-detections-${new Date().toISOString().split('T')[0]}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    
    console.log('Detection data exported');
}

// Example of real-time monitoring
function setupRealTimeMonitoring(service) {
    console.log('Setting up real-time monitoring...');
    
    let detectionCount = 0;
    let lastDetectionTime = null;
    
    service.setCallbacks({
        onFaceDetected: (logEntry) => {
            detectionCount++;
            lastDetectionTime = logEntry.date;
            
            console.log(`Detection #${detectionCount}:`, {
                name: logEntry.name,
                uuid: logEntry.uuid,
                confidence: (logEntry.confidence * 100).toFixed(1) + '%',
                time: logEntry.date.toLocaleTimeString()
            });
            
            // Alert for high confidence detections
            if (logEntry.confidence > 0.9) {
                console.log('🎯 High confidence detection!', logEntry.name);
            }
            
            // Alert for specific persons (example)
            if (logEntry.name.toLowerCase().includes('admin')) {
                console.log('🔐 Admin detected!', logEntry.name);
            }
        },
        
        onConnectionChanged: (connected) => {
            if (connected) {
                console.log('✅ Monitoring started');
            } else {
                console.log('❌ Monitoring stopped - connection lost');
            }
        }
    });
}

// Utility function to format detection data for display
function formatDetectionForDisplay(logEntry) {
    return {
        id: logEntry.id,
        person: {
            name: logEntry.name,
            uuid: logEntry.uuid
        },
        detection: {
            confidence: Math.round(logEntry.confidence * 100) + '%',
            timestamp: logEntry.date.toLocaleString(),
            relativeTime: getRelativeTime(logEntry.date)
        },
        hasImage: !!logEntry.image
    };
}

// Utility function to get relative time
function getRelativeTime(date) {
    const now = new Date();
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / (1000 * 60));
    const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    
    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins} minute${diffMins > 1 ? 's' : ''} ago`;
    if (diffHours < 24) return `${diffHours} hour${diffHours > 1 ? 's' : ''} ago`;
    return `${diffDays} day${diffDays > 1 ? 's' : ''} ago`;
}

// Make functions available globally for testing
window.testFaceRecognitionService = testFaceRecognitionService;
window.demonstrateLogFiltering = demonstrateLogFiltering;
window.exportDetectionData = exportDetectionData;
window.setupRealTimeMonitoring = setupRealTimeMonitoring;
window.formatDetectionForDisplay = formatDetectionForDisplay;
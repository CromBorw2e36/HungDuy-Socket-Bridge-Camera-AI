/**
 * Face Recognition Socket Service
 * Handles WebSocket connection, image streaming, and face detection logging
 */

class FaceRecognitionService {
    constructor() {
        this.socket = null;
        this.isConnected = false;
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 5;
        this.reconnectDelay = 3000;
        
        // Event callbacks
        this.onImageReceived = null;
        this.onFaceDetected = null;
        this.onConnectionChanged = null;
        this.onError = null;
        
        // Face detection log
        this.faceLog = [];
        this.maxLogSize = 100;
        
        // Configuration
        this.config = {
            host: 'localhost',
            port: 8765,
            protocol: 'ws'
        };
    }
    
    /**
     * Configure the service
     * @param {Object} config - Configuration object
     */
    configure(config) {
        this.config = { ...this.config, ...config };
    }
    
    /**
     * Connect to WebSocket server
     * @returns {Promise<boolean>} Connection success
     */
    async connect() {
        return new Promise((resolve, reject) => {
            try {
                const url = `${this.config.protocol}://${this.config.host}:${this.config.port}`;
                console.log(`Connecting to: ${url}`);
                
                this.socket = new WebSocket(url);
                
                this.socket.onopen = () => {
                    this.isConnected = true;
                    this.reconnectAttempts = 0;
                    console.log('WebSocket connected successfully');
                    
                    if (this.onConnectionChanged) {
                        this.onConnectionChanged(true);
                    }
                    
                    resolve(true);
                };
                
                this.socket.onmessage = (event) => {
                    this.handleMessage(event.data);
                };
                
                this.socket.onclose = (event) => {
                    this.isConnected = false;
                    console.log('WebSocket connection closed:', event.code, event.reason);
                    
                    if (this.onConnectionChanged) {
                        this.onConnectionChanged(false);
                    }
                    
                    // Auto-reconnect if not intentionally closed
                    if (event.code !== 1000 && this.reconnectAttempts < this.maxReconnectAttempts) {
                        this.attemptReconnect();
                    }
                };
                
                this.socket.onerror = (error) => {
                    console.error('WebSocket error:', error);
                    
                    if (this.onError) {
                        this.onError(error);
                    }
                    
                    reject(error);
                };
                
            } catch (error) {
                console.error('Failed to create WebSocket:', error);
                reject(error);
            }
        });
    }
    
    /**
     * Disconnect from WebSocket server
     */
    disconnect() {
        if (this.socket) {
            this.socket.close(1000, 'User disconnected');
            this.socket = null;
        }
        this.isConnected = false;
        this.reconnectAttempts = this.maxReconnectAttempts; // Prevent auto-reconnect
    }
    
    /**
     * Attempt to reconnect with delay
     */
    attemptReconnect() {
        this.reconnectAttempts++;
        console.log(`Attempting to reconnect (${this.reconnectAttempts}/${this.maxReconnectAttempts})...`);
        
        setTimeout(() => {
            this.connect().catch(error => {
                console.error('Reconnection failed:', error);
            });
        }, this.reconnectDelay);
    }
    
    /**
     * Handle incoming WebSocket messages
     * @param {string} data - Message data
     */
    handleMessage(data) {
        try {
            const message = JSON.parse(data);
            
            if (message.type === 'frame') {
                this.processFrame(message);
            } else {
                console.log('Unknown message type:', message.type);
            }
            
        } catch (error) {
            // Handle simple string format: UUID:xxx|NAME:xxx|CONFIDENCE:xxx|IMAGE:xxx
            if (data.includes('UUID:')) {
                this.processSimpleFormat(data);
            } else {
                console.error('Error parsing message:', error);
            }
        }
    }
    
    /**
     * Process frame message (JSON format)
     * @param {Object} message - Frame message
     */
    processFrame(message) {
        const { image, recognition, timestamp } = message;
        
        // Stream image
        if (image && this.onImageReceived) {
            const imageUrl = `data:image/jpeg;base64,${image}`;
            this.onImageReceived(imageUrl, timestamp);
        }
        
        // Process face detection
        if (recognition && recognition.uuid && recognition.name) {
            this.logFaceDetection(image, recognition.name, recognition.uuid, recognition.confidence, timestamp);
        }
    }
    
    /**
     * Process simple string format
     * @param {string} data - String data
     */
    processSimpleFormat(data) {
        const parts = data.split('|');
        let uuid = '', name = '', confidence = '', imageData = '';
        
        parts.forEach(part => {
            if (part.startsWith('UUID:')) {
                uuid = part.substring(5);
            } else if (part.startsWith('NAME:')) {
                name = part.substring(5);
            } else if (part.startsWith('CONFIDENCE:')) {
                confidence = part.substring(11);
            } else if (part.startsWith('IMAGE:')) {
                imageData = part.substring(6);
            }
        });
        
        // Stream image
        if (imageData && this.onImageReceived) {
            const imageUrl = `data:image/jpeg;base64,${imageData}`;
            this.onImageReceived(imageUrl, Date.now());
        }
        
        // Process face detection
        if (uuid && name) {
            this.logFaceDetection(imageData, name, uuid, parseFloat(confidence), Date.now());
        }
    }
    
    /**
     * Log face detection event
     * @param {string} image - Base64 image data
     * @param {string} name - Person name
     * @param {string} uuid - Person UUID
     * @param {number} confidence - Detection confidence
     * @param {number} timestamp - Detection timestamp
     */
    logFaceDetection(image, name, uuid, confidence, timestamp) {
        const logEntry = {
            id: this.generateLogId(),
            image: image,
            name: name,
            uuid: uuid,
            confidence: confidence,
            timestamp: timestamp,
            date: new Date(timestamp)
        };
        
        // Add to log
        this.faceLog.unshift(logEntry);
        
        // Maintain max log size
        if (this.faceLog.length > this.maxLogSize) {
            this.faceLog = this.faceLog.slice(0, this.maxLogSize);
        }
        
        console.log(`Face detected: ${name} (${uuid}) - Confidence: ${confidence.toFixed(3)}`);
        
        // Trigger callback
        if (this.onFaceDetected) {
            this.onFaceDetected(logEntry);
        }
    }
    
    /**
     * Get face detection log
     * @param {number} limit - Number of entries to return
     * @returns {Array} Face detection log entries
     */
    getLogFace(limit = null) {
        if (limit) {
            return this.faceLog.slice(0, limit);
        }
        return [...this.faceLog];
    }
    
    /**
     * Get face detection log by UUID
     * @param {string} uuid - Person UUID
     * @returns {Array} Face detection log entries for the UUID
     */
    getLogFaceByUuid(uuid) {
        return this.faceLog.filter(entry => entry.uuid === uuid);
    }
    
    /**
     * Get face detection log by name
     * @param {string} name - Person name
     * @returns {Array} Face detection log entries for the name
     */
    getLogFaceByName(name) {
        return this.faceLog.filter(entry => entry.name.toLowerCase().includes(name.toLowerCase()));
    }
    
    /**
     * Get face detection log within time range
     * @param {Date} startDate - Start date
     * @param {Date} endDate - End date
     * @returns {Array} Face detection log entries within range
     */
    getLogFaceByDateRange(startDate, endDate) {
        return this.faceLog.filter(entry => 
            entry.date >= startDate && entry.date <= endDate
        );
    }
    
    /**
     * Clear face detection log
     */
    clearLogFace() {
        this.faceLog = [];
        console.log('Face detection log cleared');
    }
    
    /**
     * Export face detection log as JSON
     * @returns {string} JSON string of face log
     */
    exportLogFace() {
        return JSON.stringify(this.faceLog, null, 2);
    }
    
    /**
     * Generate unique log ID
     * @returns {string} Unique ID
     */
    generateLogId() {
        return Date.now().toString(36) + Math.random().toString(36).substr(2);
    }
    
    /**
     * Get connection status
     * @returns {boolean} Connection status
     */
    getConnectionStatus() {
        return this.isConnected;
    }
    
    /**
     * Get service statistics
     * @returns {Object} Service statistics
     */
    getStatistics() {
        return {
            isConnected: this.isConnected,
            totalDetections: this.faceLog.length,
            uniquePersons: new Set(this.faceLog.map(entry => entry.uuid)).size,
            reconnectAttempts: this.reconnectAttempts,
            lastDetection: this.faceLog.length > 0 ? this.faceLog[0].date : null
        };
    }
    
    /**
     * Set event callbacks
     * @param {Object} callbacks - Event callback functions
     */
    setCallbacks(callbacks) {
        if (callbacks.onImageReceived) this.onImageReceived = callbacks.onImageReceived;
        if (callbacks.onFaceDetected) this.onFaceDetected = callbacks.onFaceDetected;
        if (callbacks.onConnectionChanged) this.onConnectionChanged = callbacks.onConnectionChanged;
        if (callbacks.onError) this.onError = callbacks.onError;
    }
}

/**
 * UI Controller for Face Recognition Service
 */
class FaceRecognitionUI {
    constructor(service) {
        this.service = service;
        this.elements = {};
        this.isStreaming = false;
        
        this.initializeElements();
        this.setupEventListeners();
        this.setupServiceCallbacks();
    }
    
    /**
     * Initialize DOM elements
     */
    initializeElements() {
        this.elements = {
            connectBtn: document.getElementById('connectBtn'),
            disconnectBtn: document.getElementById('disconnectBtn'),
            statusIndicator: document.getElementById('statusIndicator'),
            videoStream: document.getElementById('videoStream'),
            currentDetection: document.getElementById('currentDetection'),
            detectionHistory: document.getElementById('detectionHistory'),
            statistics: document.getElementById('statistics'),
            exportBtn: document.getElementById('exportBtn'),
            clearBtn: document.getElementById('clearBtn')
        };
    }
    
    /**
     * Setup event listeners
     */
    setupEventListeners() {
        if (this.elements.connectBtn) {
            this.elements.connectBtn.addEventListener('click', () => this.connect());
        }
        
        if (this.elements.disconnectBtn) {
            this.elements.disconnectBtn.addEventListener('click', () => this.disconnect());
        }
        
        if (this.elements.exportBtn) {
            this.elements.exportBtn.addEventListener('click', () => this.exportLog());
        }
        
        if (this.elements.clearBtn) {
            this.elements.clearBtn.addEventListener('click', () => this.clearLog());
        }
    }
    
    /**
     * Setup service event callbacks
     */
    setupServiceCallbacks() {
        this.service.setCallbacks({
            onImageReceived: (imageUrl, timestamp) => this.updateVideoStream(imageUrl),
            onFaceDetected: (logEntry) => this.updateDetection(logEntry),
            onConnectionChanged: (connected) => this.updateConnectionStatus(connected),
            onError: (error) => this.showError(error)
        });
    }
    
    /**
     * Connect to service
     */
    async connect() {
        try {
            await this.service.connect();
            this.updateUI();
        } catch (error) {
            this.showError('Connection failed: ' + error.message);
        }
    }
    
    /**
     * Disconnect from service
     */
    disconnect() {
        this.service.disconnect();
        this.updateUI();
    }
    
    /**
     * Update video stream
     * @param {string} imageUrl - Image data URL
     */
    updateVideoStream(imageUrl) {
        if (this.elements.videoStream) {
            this.elements.videoStream.src = imageUrl;
            this.isStreaming = true;
        }
    }
    
    /**
     * Update face detection display
     * @param {Object} logEntry - Face detection log entry
     */
    updateDetection(logEntry) {
        // Update current detection
        if (this.elements.currentDetection) {
            this.elements.currentDetection.innerHTML = `
                <div class="detection-card">
                    <img src="data:image/jpeg;base64,${logEntry.image}" alt="Detection" class="detection-image">
                    <div class="detection-info">
                        <h3>${logEntry.name}</h3>
                        <p>UUID: ${logEntry.uuid}</p>
                        <p>Confidence: ${(logEntry.confidence * 100).toFixed(1)}%</p>
                        <p>Time: ${logEntry.date.toLocaleTimeString()}</p>
                    </div>
                </div>
            `;
        }
        
        // Update detection history
        this.updateDetectionHistory();
        
        // Update statistics
        this.updateStatistics();
    }
    
    /**
     * Update detection history display
     */
    updateDetectionHistory() {
        if (!this.elements.detectionHistory) return;
        
        const log = this.service.getLogFace(10); // Get last 10 detections
        
        this.elements.detectionHistory.innerHTML = log.map(entry => `
            <div class="history-item">
                <img src="data:image/jpeg;base64,${entry.image}" alt="${entry.name}" class="history-image">
                <div class="history-info">
                    <strong>${entry.name}</strong><br>
                    ${entry.uuid}<br>
                    ${(entry.confidence * 100).toFixed(1)}%<br>
                    ${entry.date.toLocaleString()}
                </div>
            </div>
        `).join('');
    }
    
    /**
     * Update connection status display
     * @param {boolean} connected - Connection status
     */
    updateConnectionStatus(connected) {
        if (this.elements.statusIndicator) {
            this.elements.statusIndicator.className = connected ? 'status-connected' : 'status-disconnected';
            this.elements.statusIndicator.textContent = connected ? 'Connected' : 'Disconnected';
        }
        
        this.updateUI();
    }
    
    /**
     * Update statistics display
     */
    updateStatistics() {
        if (!this.elements.statistics) return;
        
        const stats = this.service.getStatistics();
        
        this.elements.statistics.innerHTML = `
            <div class="stats-grid">
                <div class="stat-item">
                    <label>Status:</label>
                    <span class="${stats.isConnected ? 'status-connected' : 'status-disconnected'}">
                        ${stats.isConnected ? 'Connected' : 'Disconnected'}
                    </span>
                </div>
                <div class="stat-item">
                    <label>Total Detections:</label>
                    <span>${stats.totalDetections}</span>
                </div>
                <div class="stat-item">
                    <label>Unique Persons:</label>
                    <span>${stats.uniquePersons}</span>
                </div>
                <div class="stat-item">
                    <label>Last Detection:</label>
                    <span>${stats.lastDetection ? stats.lastDetection.toLocaleString() : 'None'}</span>
                </div>
            </div>
        `;
    }
    
    /**
     * Update UI button states
     */
    updateUI() {
        const connected = this.service.getConnectionStatus();
        
        if (this.elements.connectBtn) {
            this.elements.connectBtn.disabled = connected;
        }
        
        if (this.elements.disconnectBtn) {
            this.elements.disconnectBtn.disabled = !connected;
        }
    }
    
    /**
     * Export face detection log
     */
    exportLog() {
        const logData = this.service.exportLogFace();
        const blob = new Blob([logData], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        
        const a = document.createElement('a');
        a.href = url;
        a.download = `face-detection-log-${new Date().toISOString().split('T')[0]}.json`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }
    
    /**
     * Clear face detection log
     */
    clearLog() {
        if (confirm('Are you sure you want to clear the face detection log?')) {
            this.service.clearLogFace();
            this.updateDetectionHistory();
            this.updateStatistics();
            
            if (this.elements.currentDetection) {
                this.elements.currentDetection.innerHTML = '<p>No recent detections</p>';
            }
        }
    }
    
    /**
     * Show error message
     * @param {string|Error} error - Error message or object
     */
    showError(error) {
        const message = error instanceof Error ? error.message : error;
        console.error('UI Error:', message);
        
        // You can implement a toast notification or modal here
        alert('Error: ' + message);
    }
}

// Initialize service when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    // Create service instance
    const faceService = new FaceRecognitionService();
    
    // Configure service if needed
    faceService.configure({
        host: window.location.hostname || 'localhost',
        port: 8765
    });
    
    // Create UI controller
    const faceUI = new FaceRecognitionUI(faceService);
    
    // Make service globally available for debugging
    window.faceService = faceService;
    window.faceUI = faceUI;
    
    console.log('Face Recognition Service initialized');
});

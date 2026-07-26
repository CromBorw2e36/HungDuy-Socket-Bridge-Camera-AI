import asyncio
import websockets
import json
import base64
import cv2
import threading
import queue
import time

class WebSocketServer:
    def __init__(self, host='0.0.0.0', port=8765):
        self.host = host
        self.port = port
        self.clients = set()
        self.frame_queue = queue.Queue(maxsize=5)  # Increase queue size to prevent dropping
        self.running = False
        self.last_frame_data = None  # Store last frame for new clients
        self.on_first_connect_callback = None
        self.on_last_disconnect_callback = None
        
    async def register_client(self, websocket):
        """Register a new client"""
        is_first_client = len(self.clients) == 0
        self.clients.add(websocket)
        print(f"WebSocket client connected. Total clients: {len(self.clients)}")
        
        # Call callback for first client connection
        if is_first_client and self.on_first_connect_callback:
            self.on_first_connect_callback()
        
    async def unregister_client(self, websocket):
        """Unregister a client"""
        self.clients.discard(websocket)
        print(f"WebSocket client disconnected. Total clients: {len(self.clients)}")
        
        # Call callback if this was the last client
        if len(self.clients) == 0 and self.on_last_disconnect_callback:
            self.on_last_disconnect_callback()
        
    async def handle_client(self, websocket):
        """Handle individual client connection"""
        await self.register_client(websocket)
        try:
            await websocket.wait_closed()
        finally:
            await self.unregister_client(websocket)
            
    async def broadcast_frame(self):
        """Broadcast frames to all connected clients"""
        while self.running:
            if self.clients and not self.frame_queue.empty():
                try:
                    frame_data = self.frame_queue.get_nowait()
                    
                    # Send to all connected clients
                    disconnected_clients = set()
                    for client in self.clients.copy():
                        try:
                            await client.send(json.dumps(frame_data))
                        except websockets.exceptions.ConnectionClosed:
                            disconnected_clients.add(client)
                        except Exception as e:
                            print(f"Error sending to client: {e}")
                            disconnected_clients.add(client)
                    
                    # Remove disconnected clients
                    for client in disconnected_clients:
                        await self.unregister_client(client)
                        
                except queue.Empty:
                    pass
                except Exception as e:
                    print(f"Broadcast error: {e}")
                    
            await asyncio.sleep(0.033)  # ~30 FPS
            
    def add_frame(self, frame, uuid="", name="", confidence=0.0, cropped_face=None):
        """Add frame to broadcast queue"""
        try:
            # Encode frame to JPEG
            _, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 70])
            frame_data = base64.b64encode(buffer).decode('utf-8')
            
            # Encode cropped face if available
            face_data = ""
            if cropped_face is not None and cropped_face.size > 0:
                _, face_buffer = cv2.imencode('.jpg', cropped_face, [cv2.IMWRITE_JPEG_QUALITY, 85])
                face_data = base64.b64encode(face_buffer).decode('utf-8')
            
            message = {
                "type": "frame",
                "timestamp": time.time(),
                "image": frame_data,
                "face": face_data,
                "recognition": {
                    "uuid": uuid.strip() if uuid else "",
                    "name": name.strip() if name else "",
                    "confidence": float(confidence) if confidence else 0.0
                }
            }
            
            # Store last frame data
            self.last_frame_data = message
            
            # Clear old frames if queue is getting full
            while self.frame_queue.qsize() >= 3:
                try:
                    self.frame_queue.get_nowait()
                except queue.Empty:
                    break
                    
            self.frame_queue.put(message)

        except Exception as e:
            print(f"Error adding frame: {e}")
            
    async def start_server(self):
        """Start the WebSocket server"""
        self.running = True
        
        # Start broadcast task
        broadcast_task = asyncio.create_task(self.broadcast_frame())
        
        # Start WebSocket server
        async with websockets.serve(self.handle_client, self.host, self.port):
            print(f"WebSocket server started on ws://{self.host}:{self.port}")
            try:
                await asyncio.Future()  # Run forever
            except KeyboardInterrupt:
                print("WebSocket server shutting down...")
            finally:
                self.running = False
                broadcast_task.cancel()
                
    def start_in_thread(self):
        """Start the WebSocket server in a separate thread"""
        def run_server():
            asyncio.run(self.start_server())
            
        server_thread = threading.Thread(target=run_server, daemon=True)
        server_thread.start()
        return server_thread

# Global WebSocket server instance
websocket_server = None

def initialize_websocket_server(host='0.0.0.0', port=8765):
    """Initialize and start WebSocket server"""
    global websocket_server
    websocket_server = WebSocketServer(host, port)
    return websocket_server.start_in_thread()

def send_frame_to_websocket(frame, uuid="", name="", confidence=0.0, cropped_face=None):
    """Send frame to WebSocket clients"""
    global websocket_server
    if websocket_server:
        websocket_server.add_frame(frame, uuid, name, confidence, cropped_face)

def set_websocket_callbacks(on_first_connect=None, on_last_disconnect=None):
    """Set callbacks for WebSocket connection events"""
    global websocket_server
    if websocket_server:
        websocket_server.on_first_connect_callback = on_first_connect
        websocket_server.on_last_disconnect_callback = on_last_disconnect

if __name__ == "__main__":
    # Test the WebSocket server
    server = WebSocketServer()
    asyncio.run(server.start_server())
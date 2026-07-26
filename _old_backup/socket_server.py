import socket
import threading
import json
import base64
import cv2
import time
from typing import Dict, List
import struct

class WebSocketServer:
    def __init__(self, host='localhost', port=8765):
        self.host = host
        self.port = port
        self.clients = []
        self.server_socket = None
        self.running = False
        
    def start_server(self):
        """Start the socket server"""
        try:
            self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.server_socket.bind((self.host, self.port))
            self.server_socket.listen(5)
            self.running = True
            
            print(f"Socket server started on {self.host}:{self.port}")
            
            while self.running:
                try:
                    client_socket, address = self.server_socket.accept()
                    print(f"New client connected from {address}")
                    
                    client_thread = threading.Thread(
                        target=self.handle_client, 
                        args=(client_socket, address)
                    )
                    client_thread.daemon = True
                    client_thread.start()
                    
                except socket.error as e:
                    if self.running:
                        print(f"Socket error: {e}")
                        
        except Exception as e:
            print(f"Server error: {e}")
        finally:
            self.stop_server()
            
    def handle_client(self, client_socket, address):
        """Handle individual client connection"""
        try:
            self.clients.append(client_socket)
            
            while self.running:
                try:
                    # Keep connection alive with ping
                    client_socket.settimeout(1.0)
                    time.sleep(0.1)
                except socket.timeout:
                    continue
                except socket.error:
                    break
                    
        except Exception as e:
            print(f"Client handler error: {e}")
        finally:
            self.remove_client(client_socket)
            print(f"Client {address} disconnected")
            
    def remove_client(self, client_socket):
        """Remove client from active clients list"""
        try:
            if client_socket in self.clients:
                self.clients.remove(client_socket)
            client_socket.close()
        except:
            pass
            
    def broadcast_frame(self, frame, uuid="", name="", confidence=0.0):
        """Broadcast frame with recognition data to all connected clients"""
        if not self.clients:
            return
            
        try:
            # Encode frame to JPEG
            _, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
            frame_data = base64.b64encode(buffer).decode('utf-8')
            
            # Create message with frame and recognition data
            message = {
                "type": "frame",
                "timestamp": time.time(),
                "image": frame_data,
                "recognition": {
                    "uuid": uuid,
                    "name": name,
                    "confidence": confidence
                }
            }
            
            # Convert to JSON and get size
            json_data = json.dumps(message)
            message_size = len(json_data.encode('utf-8'))
            
            # Send to all clients
            disconnected_clients = []
            for client in self.clients[:]:  # Copy list to avoid modification during iteration
                try:
                    # Send message size first (4 bytes)
                    client.send(struct.pack('!I', message_size))
                    # Send the actual message
                    client.send(json_data.encode('utf-8'))
                except socket.error:
                    disconnected_clients.append(client)
                    
            # Remove disconnected clients
            for client in disconnected_clients:
                self.remove_client(client)
                
        except Exception as e:
            print(f"Error broadcasting frame: {e}")
            
    def stop_server(self):
        """Stop the socket server"""
        self.running = False
        
        # Close all client connections
        for client in self.clients[:]:
            self.remove_client(client)
            
        # Close server socket
        if self.server_socket:
            try:
                self.server_socket.close()
            except:
                pass
                
        print("Socket server stopped")

class SimpleSocketServer:
    """Simplified socket server for basic TCP communication"""
    def __init__(self, host='localhost', port=8080):
        self.host = host
        self.port = port
        self.clients = []
        self.server_socket = None
        self.running = False
        self.detection_thread = None
        self.on_first_connect_callback = None
        self.on_last_disconnect_callback = None
        
    def start_server(self):
        """Start the simple socket server"""
        try:
            self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.server_socket.bind((self.host, self.port))
            self.server_socket.listen(5)
            self.running = True
            
            print(f"Simple socket server started on {self.host}:{self.port}")
            
            while self.running:
                try:
                    client_socket, address = self.server_socket.accept()
                    print(f"New client connected from {address}")
                    
                    # Check if this is the first client
                    is_first_client = len(self.clients) == 0
                    
                    self.clients.append(client_socket)
                    
                    # Call callback for first client connection
                    if is_first_client and self.on_first_connect_callback:
                        self.on_first_connect_callback()
                    
                    client_thread = threading.Thread(
                        target=self.handle_simple_client, 
                        args=(client_socket, address)
                    )
                    client_thread.daemon = True
                    client_thread.start()
                    
                except socket.error as e:
                    if self.running:
                        print(f"Socket error: {e}")
                        
        except Exception as e:
            print(f"Server error: {e}")
        finally:
            self.stop_server()
            
    def handle_simple_client(self, client_socket, address):
        """Handle simple client connection"""
        try:
            while self.running:
                try:
                    client_socket.settimeout(1.0)
                    time.sleep(0.1)
                except socket.timeout:
                    continue
                except socket.error:
                    break
                    
        except Exception as e:
            print(f"Simple client handler error: {e}")
        finally:
            self.remove_client(client_socket)
            print(f"Simple client {address} disconnected")
            
    def remove_client(self, client_socket):
        """Remove client from active clients list"""
        try:
            if client_socket in self.clients:
                self.clients.remove(client_socket)
            client_socket.close()
            
            # Call callback if this was the last client
            if len(self.clients) == 0 and self.on_last_disconnect_callback:
                self.on_last_disconnect_callback()
                
        except:
            pass
            
    def send_data(self, uuid="", name="", confidence=0.0, frame=None, cropped_face=None):
        """Send recognition data to all connected clients"""
        if not self.clients:
            return
            
        try:
            # Encode main frame
            frame_data = ""
            if frame is not None:
                _, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 70])
                frame_data = base64.b64encode(buffer).decode('utf-8')
            
            # Encode cropped face
            face_data = ""
            if cropped_face is not None and cropped_face.size > 0:
                _, buffer = cv2.imencode('.jpg', cropped_face, [cv2.IMWRITE_JPEG_QUALITY, 85])
                face_data = base64.b64encode(buffer).decode('utf-8')
            
            message = f"UUID:{uuid}|NAME:{name}|CONFIDENCE:{confidence:.3f}|IMAGE:{frame_data}|FACE:{face_data}\n"
            
            # Send to all clients
            disconnected_clients = []
            for client in self.clients[:]:
                try:
                    client.send(message.encode('utf-8'))
                except socket.error:
                    disconnected_clients.append(client)
                    
            # Remove disconnected clients
            for client in disconnected_clients:
                self.remove_client(client)
                
        except Exception as e:
            print(f"Error sending data: {e}")
            
    def stop_server(self):
        """Stop the simple socket server"""
        self.running = False
        
        # Close all client connections
        for client in self.clients[:]:
            self.remove_client(client)
            
        # Close server socket
        if self.server_socket:
            try:
                self.server_socket.close()
            except:
                pass
                
        print("Simple socket server stopped")
    
    def set_connection_callbacks(self, on_first_connect=None, on_last_disconnect=None):
        """Set callbacks for client connection events"""
        self.on_first_connect_callback = on_first_connect
        self.on_last_disconnect_callback = on_last_disconnect
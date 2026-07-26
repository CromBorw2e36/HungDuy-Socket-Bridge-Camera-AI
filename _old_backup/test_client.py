import socket
import struct
import json
import base64
import cv2
import numpy as np
import threading
import time

class SocketClient:
    def __init__(self, host='localhost', port=8080):
        self.host = host
        self.port = port
        self.socket = None
        self.running = False
        
    def connect(self):
        """Connect to the socket server"""
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socket.connect((self.host, self.port))
            self.running = True
            print(f"Connected to server at {self.host}:{self.port}")
            
            # Start receiving thread
            receive_thread = threading.Thread(target=self.receive_data, daemon=True)
            receive_thread.start()
            
            return True
            
        except Exception as e:
            print(f"Failed to connect: {e}")
            return False
            
    def receive_data(self):
        """Receive data from server"""
        buffer = b''
        
        while self.running:
            try:
                # Receive data
                data = self.socket.recv(4096)
                if not data:
                    break
                    
                buffer += data
                
                # Process complete messages
                while b'\n' in buffer:
                    line, buffer = buffer.split(b'\n', 1)
                    message = line.decode('utf-8')
                    
                    if message:
                        self.process_message(message)
                        
            except socket.error as e:
                print(f"Socket error: {e}")
                break
            except Exception as e:
                print(f"Receive error: {e}")
                break
                
        print("Disconnected from server")
        
    def process_message(self, message):
        """Process received message"""
        try:
            # Parse the message format: UUID:xxx|NAME:xxx|CONFIDENCE:xxx|IMAGE:xxx
            if message.startswith('UUID:'):
                parts = message.split('|')
                uuid = ""
                name = ""
                confidence = ""
                image_data = ""
                
                for part in parts:
                    if part.startswith('UUID:'):
                        uuid = part[5:]
                    elif part.startswith('NAME:'):
                        name = part[5:]
                    elif part.startswith('CONFIDENCE:'):
                        confidence = part[11:]
                    elif part.startswith('IMAGE:'):
                        image_data = part[6:]
                
                # Display recognition info if available
                if uuid and name:
                    print(f"Recognition: UUID={uuid}, Name={name}, Confidence={confidence}")
                
                # Display image if available
                if image_data and len(image_data) > 100:  # Basic check for valid image data
                    try:
                        # Decode base64 image
                        img_bytes = base64.b64decode(image_data)
                        img_array = np.frombuffer(img_bytes, dtype=np.uint8)
                        frame = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
                        
                        if frame is not None:
                            # Add text overlay with recognition info
                            if uuid and name:
                                cv2.putText(frame, f"UUID: {uuid}", (10, 30), 
                                          cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                                cv2.putText(frame, f"Name: {name}", (10, 60), 
                                          cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                                cv2.putText(frame, f"Confidence: {confidence}", (10, 90), 
                                          cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                            
                            cv2.imshow('Face Recognition Client', frame)
                            
                            # Exit on 'q' key press
                            if cv2.waitKey(1) & 0xFF == ord('q'):
                                self.disconnect()
                                
                    except Exception as e:
                        print(f"Error decoding image: {e}")
                        
        except Exception as e:
            print(f"Error processing message: {e}")
            
    def disconnect(self):
        """Disconnect from server"""
        self.running = False
        if self.socket:
            try:
                self.socket.close()
            except:
                pass
        cv2.destroyAllWindows()

def main():
    client = SocketClient('localhost', 8080)
    
    print("Face Recognition Socket Client")
    print("Connecting to server...")
    
    if client.connect():
        print("Connected! Press 'q' in the video window to quit.")
        
        try:
            # Keep the main thread alive
            while client.running:
                time.sleep(0.1)
        except KeyboardInterrupt:
            print("\nShutting down...")
            
        client.disconnect()
    else:
        print("Failed to connect to server.")

if __name__ == "__main__":
    main()
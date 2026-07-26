import os
import platform
import threading
from pathlib import Path
from hailo_inference import HailoAsyncInference
import queue
from functools import partial
import numpy as np
from PIL import Image
import cv2
from Utils import default_preprocessv2,rescale_network_outputs,postprocess_scrfd_outputs,plot_boxes_on_image
import time
from dataclasses import dataclass, field
import pandas as pd
from typing import List
import requests
import json
import faiss
import signal
import sys
from websocket_server import initialize_websocket_server, send_frame_to_websocket, set_websocket_callbacks

# Log có emoji/tiếng Việt: ép UTF-8 để không chết khi stdout bị redirect (cp1252/cp1258)
for _stream in (sys.stdout, sys.stderr):
    if _stream is not None and hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

# Mọi tài nguyên neo theo vị trí file này — không phụ thuộc CWD của launcher
BASE = Path(__file__).resolve().parent

# HEADLESS=1/0 để ép; mặc định: Linux không có DISPLAY -> headless
_headless_env = os.environ.get("HEADLESS")
if _headless_env is not None:
    HEADLESS = _headless_env.strip() not in ("0", "false", "False", "")
else:
    HEADLESS = (platform.system() != "Windows") and not os.environ.get("DISPLAY")

CAMERA_INDEX = int(os.environ.get("CAMERA_INDEX", "0"))

face_detector_model = str(BASE / "scrfd_2.5g.hef")
face_recognition_model = str(BASE / "arcface_r50.hef")

input_queue_face = queue.Queue()
output_queue_face = queue.Queue()
output_queue_face_rec = queue.Queue()

Clean_BBOX = False
running = True
detection_active = False
cap = None

def get_employees_from_api():
    try:
        api_url = "https://hrm.hungduy.vn/User/GetFaceDetected"
        payload = {"apiKey": "HungDuyHRM@2024"}
        
        print("🌐 Đang gọi API để lấy dữ liệu nhân viên...")
        response = requests.post(api_url, data=payload, timeout=10)
        
        if response.status_code == 200:
            result = response.json()
            if result.get("Data"):
                # Parse JSON string trong Data field
                employees_data = json.loads(result["Data"])
                df = pd.DataFrame(employees_data)
                print(f"✅ Lấy dữ liệu từ API thành công: {len(df)} nhân viên")
                return df
            else:
                print("⚠️ API trả về nhưng không có dữ liệu")
                return pd.DataFrame()
        else:
            print(f"❌ API trả về lỗi: {response.status_code}")
            return pd.DataFrame()
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Lỗi kết nối API: {e}")
        return pd.DataFrame()
    except json.JSONDecodeError as e:
        print(f"❌ Lỗi parse JSON: {e}")
        return pd.DataFrame()
    except Exception as e:
        print(f"❌ Lỗi không xác định: {e}")
        return pd.DataFrame()

# Signal handler for graceful shutdown
def signal_handler(sig, frame):
    global running
    print("\nShutting down gracefully...")
    running = False

employee = []
BASE_DIR = str(BASE / "employees_data")

# Dữ liệu nhân viên được nạp trong __main__ — không gọi API lúc import
df = pd.DataFrame()

def fetch_employees_with_retry(attempts=3, delay=5):
    result = pd.DataFrame()
    for i in range(attempts):
        result = get_employees_from_api()
        if not result.empty:
            return result
        if i < attempts - 1:
            print(f"⚠️ API chưa có dữ liệu, thử lại sau {delay}s ({i + 1}/{attempts})...")
            time.sleep(delay)
    return result

@dataclass
class Face:
    url: str
    embedding: List[float]

    def __init__(self, url, embedding):
        self.url = url
        self.embedding = embedding

@dataclass
class Employee:
    uid: str
    name: str
    face: List[Face]

    def __init__(self, uid, name):
        self.uid = uid
        self.name = name
        self.face = []
    def appendEncode(self, encode: Face):
        self.face.append(encode)

def inference_callback_face(
    completion_info,
    bindings_list: list,
    input_batch: list,
    preprocessed_batch: list,
    output_queue: queue.Queue,
    data: object = None) -> None:
    try:
        global Clean_BBOX
        if completion_info.exception:
            print(f'{{"status":"error", "data": "Inference error: {completion_info.exception}" }}')
        else:
            outputs_s = []
            for i, bindings in enumerate(bindings_list):
                original_frame = input_batch[i]
                #outputs = {
                #    "scrfd_10g/conv42": bindings.output("scrfd_10g/conv42").get_buffer(), 
                #    "scrfd_10g/conv41": bindings.output("scrfd_10g/conv41").get_buffer(), 
                #    "scrfd_10g/conv43": bindings.output("scrfd_10g/conv43").get_buffer(), 
                #    "scrfd_10g/conv50": bindings.output("scrfd_10g/conv50").get_buffer(), 
                #    "scrfd_10g/conv49": bindings.output("scrfd_10g/conv49").get_buffer(), 
                #    "scrfd_10g/conv51": bindings.output("scrfd_10g/conv51").get_buffer(), 
                #    "scrfd_10g/conv57": bindings.output("scrfd_10g/conv57").get_buffer(), 
                #    "scrfd_10g/conv56": bindings.output("scrfd_10g/conv56").get_buffer(), 
                #    "scrfd_10g/conv58": bindings.output("scrfd_10g/conv58").get_buffer()
                #}
                outputs = {
                    "scrfd_10g/conv42": bindings.output("scrfd_2_5g/conv43").get_buffer(), 
                    "scrfd_10g/conv41": bindings.output("scrfd_2_5g/conv42").get_buffer(), 
                    "scrfd_10g/conv43": bindings.output("scrfd_2_5g/conv44").get_buffer(), 
                    "scrfd_10g/conv50": bindings.output("scrfd_2_5g/conv50").get_buffer(), 
                    "scrfd_10g/conv49": bindings.output("scrfd_2_5g/conv49").get_buffer(), 
                    "scrfd_10g/conv51": bindings.output("scrfd_2_5g/conv51").get_buffer(), 
                    "scrfd_10g/conv57": bindings.output("scrfd_2_5g/conv56").get_buffer(), 
                    "scrfd_10g/conv56": bindings.output("scrfd_2_5g/conv55").get_buffer(), 
                    "scrfd_10g/conv58": bindings.output("scrfd_2_5g/conv57").get_buffer()
                }
                #outputs = {
                #    "scrfd_10g/conv42": bindings.output("scrfd_500m/conv27").get_buffer(), 
                #    "scrfd_10g/conv41": bindings.output("scrfd_500m/conv26").get_buffer(), 
                #    "scrfd_10g/conv43": bindings.output("scrfd_500m/conv25").get_buffer(), 
                #    "scrfd_10g/conv50": bindings.output("scrfd_500m/conv33").get_buffer(), 
                #    "scrfd_10g/conv49": bindings.output("scrfd_500m/conv32").get_buffer(), 
                #    "scrfd_10g/conv51": bindings.output("scrfd_500m/conv34").get_buffer(), 
                #    "scrfd_10g/conv57": bindings.output("scrfd_500m/conv39").get_buffer(), 
                #    "scrfd_10g/conv56": bindings.output("scrfd_500m/conv38").get_buffer(), 
                #    "scrfd_10g/conv58": bindings.output("scrfd_500m/conv40").get_buffer()
                #}
                outputs_s.append(outputs)

            # Rescale outputs (similar to your example)
            rescaled_outputs = rescale_network_outputs(outputs_s)
            
            # Process detections using simplified postprocessing
            results = postprocess_scrfd_outputs(rescaled_outputs, (640, 640), score_threshold=0.7, nms_threshold=0.4)
            
            # Get detection counts
            if 'detection_boxes' in results and len(results['detection_boxes']) > 0:
                faces = results['detection_boxes'][0]
                #print(f"Detected {len(faces)} faces in batch {i}")
                if(len(faces) == 0):
                    Clean_BBOX = True
                    return
                annotated_image = plot_boxes_on_image(original_frame, results, 
                                                        original_size=original_frame.shape[:2])
                
                img, img_for_arc , landmarks, boxes = annotated_image
                for j, face in enumerate(img_for_arc):
                    img_arc = img_for_arc[0]["aligned_face"]
                    #cv2.imwrite(output_path, img_arc)
                    output_queue.put(([original_frame], [img_arc], {
                        "drawned_image": img,
                        "face": face
                    }))

                #cv2.imwrite(output_path, img_for_arc[0]["aligned_face"])
                #print(f"Saved annotated image to: {output_path}, Landmarks: {landmarks}, Boxes: {boxes}")
            else:
                print(f"No faces detected in batch {i}")
                
    except Exception as e:
        print(f'{{"status":"error", "data": "Callback error: {str(e)}" }}')
        #traceback.print_exc()

def inference_callback_face_rec(
    completion_info,
    bindings_list: list,
    input_batch: list,
    preprocessed_batch: list,
    output_queue: queue.Queue,
    data: object = None) -> None:
    try:
        if completion_info.exception:
            print(f'{{"status":"error", "data": "Inference error: {completion_info.exception}" }}')
        else:
            for i, bindings in enumerate(bindings_list):
                original_frame = input_batch[i]
                result = bindings.output().get_buffer()
                output_queue.put({
                    "original_frame": original_frame,
                    "drawned_image": data["drawned_image"],
                    "embedding": result,
                    "face": data["face"]
                })
    except Exception as e:
        print(f'{{"status":"error", "data": "Callback error: {str(e)}" }}')

def img_to_vec(img):
    try:
        img_preprocess = default_preprocessv2(img, 640, 640)
        input_queue_face.put(([img], [img_preprocess], None))
        count = 0
        while output_queue_face_rec.empty():
            count += 1
            if count > 10:
                print("Timeout waiting for face recognition output")
                return None
            time.sleep(0.1)
        item = output_queue_face_rec.get()
        bbox = item['face']['bbox']
        return item['embedding']
    except Exception as e:
        print(f'Error in img_to_vec: {str(e)}')
        return None

def save_employee(emp: Employee, emp_uuid: str):
    data = {
        "uid": emp.uid,
        "name": emp.name,
        "faces": [{"url": f.url, "embedding": f.embedding.tolist()} for f in emp.face]
    }
    # Ghi atomic: bị kill giữa chừng không để lại file JSON cụt
    final_path = os.path.join(BASE_DIR, f"{emp_uuid}.json")
    tmp_path = final_path + ".tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    os.replace(tmp_path, final_path)

def load_employees_from_json():
    """Load existing employee data from JSON files in the employees_data directory"""
    employees = []
    if not os.path.exists(BASE_DIR):
        return employees
    
    for filename in os.listdir(BASE_DIR):
        if filename.endswith('.json'):
            file_path = os.path.join(BASE_DIR, filename)
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                
                # Create Employee object
                emp = Employee(data['uid'], data['name'])
                
                # Load face encodings
                for face_data in data.get('faces', []):
                    embedding = np.array(face_data['embedding'], dtype=np.float32)
                    face = Face(face_data['url'], embedding)
                    emp.appendEncode(face)
                
                employees.append(emp)
                print(f"Loaded employee {data['name']} with {len(emp.face)} face encodings from {filename}")
                
            except Exception as e:
                print(f"Error loading employee data from {filename}: {str(e)}")
    
    return employees

def get_processed_urls(employee_list):
    """Get set of all URLs that have already been processed"""
    processed_urls = set()
    for emp in employee_list:
        for face in emp.face:
            processed_urls.add(face.url)
    return processed_urls

def find_employee_by_uid(employee_list, uid):
    """Find employee in list by UID"""
    for emp in employee_list:
        if emp.uid == uid:
            return emp
    return None

def start_webcam_detection():
    """Initialize webcam and start face detection"""
    global cap, detection_active
    
    if cap is not None and cap.isOpened():
        print("Webcam already active")
        return True
        
    print("🎥 Starting webcam and face detection...")
    if platform.system() == "Windows":
        cap = cv2.VideoCapture(CAMERA_INDEX, cv2.CAP_DSHOW)
    else:
        cap = cv2.VideoCapture(CAMERA_INDEX, cv2.CAP_V4L2)

    if not cap.isOpened():
        print(f"Error: Could not open webcam (index {CAMERA_INDEX}).")
        cap = None
        return False

    if platform.system() != "Windows":
        # UVC qua V4L2 cần MJPG mới đạt fps cao ở độ phân giải này
        cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*"MJPG"))
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 640)
    cap.set(cv2.CAP_PROP_FPS, 30)

    print("Requested 640x640")
    print("Actual:", cap.get(cv2.CAP_PROP_FRAME_WIDTH), "x", cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    print("FPS requested: 30, Actual:", cap.get(cv2.CAP_PROP_FPS))
    
    detection_active = True
    print("✅ Webcam and detection started successfully")
    return True

def stop_webcam_detection():
    """Signal the detection loop to stop; the loop releases the camera itself.

    Releasing from another thread while detection_loop is inside cap.read()
    can segfault on the V4L2 backend."""
    global detection_active
    detection_active = False
    print("📷 Webcam and detection stop requested")

def detection_loop():
    """Main detection loop that runs when clients are connected"""
    global cap, bbox, recognized_name, recognized_uuid, recognition_confidence, Clean_BBOX
    
    bbox = None
    recognized_name = ""
    recognized_uuid = ""
    recognition_confidence = 0.0
    
    print("🔄 Starting detection loop...")

    # Xả kết quả tồn của phiên trước để không chớp nhầm mặt/tên cũ
    for q in (input_queue_face, output_queue_face, output_queue_face_rec):
        while not q.empty():
            try:
                q.get_nowait()
            except queue.Empty:
                break

    while running and detection_active:
        if cap is None or not cap.isOpened():
            time.sleep(0.1)
            continue
            
        # Capture frame-by-frame
        ret, frame = cap.read()
        if not ret:
            print("Failed to grab frame")
            time.sleep(0.1)
            continue

        queue_size = input_queue_face.qsize()
        queue_arc_size = output_queue_face.qsize()
        if queue_size > 1 or queue_arc_size > 1:
            print(f"Skipping frame to avoid backlog face:{queue_size} arc:{queue_arc_size}")
        else:
            img_preprocess = default_preprocessv2(frame, 640, 640)
            input_queue_face.put(([frame], [img_preprocess], None))
        
        if Clean_BBOX:
            bbox = None
            recognized_name = ""
            recognized_uuid = ""
            recognition_confidence = 0.0
            Clean_BBOX = False

        # Process face recognition results
        cropped_face = None
        face_detected = False
        while not output_queue_face_rec.empty():
            item = output_queue_face_rec.get()
            bbox = item['face']['bbox']
            face_detected = True  # Mark that we detected a face
            
            # Crop the face from the frame
            if bbox is not None:
                # Extract bounding box coordinates
                x1, y1, x2, y2 = bbox
                # Ensure coordinates are within frame bounds
                h, w = frame.shape[:2]
                x1 = max(0, int(x1))
                y1 = max(0, int(y1))
                x2 = min(w, int(x2))
                y2 = min(h, int(y2))
                
                # Crop the face with some padding
                padding = 20  # Add 20 pixels padding around face
                x1_pad = max(0, x1 - padding)
                y1_pad = max(0, y1 - padding)
                x2_pad = min(w, x2 + padding)
                y2_pad = min(h, y2 + padding)
                
                cropped_face = frame[y1_pad:y2_pad, x1_pad:x2_pad]
                
                # Resize cropped face to standard size for consistency
                if cropped_face.size > 0:
                    cropped_face = cv2.resize(cropped_face, (150, 150))
            
            if item['embedding'] is not None:
                search_results = face_search_index.search(item['embedding'], k=3, threshold=0.6)
                if search_results:
                    # Get the best match
                    best_match = search_results[0]
                    recognized_name = best_match['employee'].name
                    recognized_uuid = best_match['employee'].uid
                    recognition_confidence = best_match['similarity']
                    #print(f"✅ RECOGNITION SUCCESS - UUID: {recognized_uuid}, Name: {recognized_name}, Confidence: {recognition_confidence:.3f}")
                else:
                    # Face detected but not recognized - set default values for unknown face
                    recognized_name = "_"
                    recognized_uuid = "_"
                    recognition_confidence = 0.0
                    #print("🔍 FACE DETECTED - Face detected but not recognized (unknown person)")

        # Draw bounding box if face was detected
        if bbox is not None:
            cv2.rectangle(frame, (bbox[0], bbox[1]), (bbox[2], bbox[3]), (0, 255, 0), 1)

        # Always send frame data to connected clients (whether face detected or not)
        try:
            # If no face was detected this frame, send empty recognition data
            if not face_detected:
                recognized_name = ""
                recognized_uuid = ""
                recognition_confidence = 0.0
                cropped_face = None
                
            send_frame_to_websocket(frame, recognized_uuid, recognized_name, recognition_confidence, cropped_face)
        except Exception as e:
            print(f"Error sending frame data: {e}")
        
        # Small delay to prevent excessive CPU usage
        #time.sleep(0.033)  # ~30 FPS
        time.sleep(0.0667)  # ~15 FPS
    
    if cap is not None:
        cap.release()
        cap = None
    print("🛑 Detection loop ended")

class FaceSearchIndex:
    def __init__(self):
        self.index = None
        self.employee_face_mapping = []  # List of (employee, face_index) tuples
        self.dimension = 512  # ArcFace embedding dimension
        
    def build_index(self, employee_list):
        """Build FAISS index from employee face embeddings"""
        embeddings = []
        self.employee_face_mapping = []
        
        for emp in employee_list:
            for face_idx, face in enumerate(emp.face):
                embeddings.append(face.embedding)
                self.employee_face_mapping.append((emp, face_idx))
        
        if not embeddings:
            print("No embeddings found to build index")
            return
            
        # Convert to numpy array
        embeddings_array = np.array(embeddings, dtype=np.float32)
        
        # Normalize embeddings for cosine similarity
        faiss.normalize_L2(embeddings_array)
        
        # Create FAISS index (IndexFlatIP for inner product, which equals cosine similarity with normalized vectors)
        self.index = faiss.IndexFlatIP(self.dimension)
        self.index.add(embeddings_array)
        
        print(f"Built FAISS index with {len(embeddings)} face embeddings from {len(employee_list)} employees")
    
    def search(self, query_embedding, k=5, threshold=0.5):
        """Search for similar faces using FAISS index"""
        if self.index is None:
            print("Index not built yet")
            return []
        
        # Normalize query embedding
        query_embedding = np.array([query_embedding], dtype=np.float32)
        faiss.normalize_L2(query_embedding)
        
        # Search
        similarities, indices = self.index.search(query_embedding, k)
        
        # Filter results by threshold and return employee info
        results = []
        for i, (similarity, idx) in enumerate(zip(similarities[0], indices[0])):
            if similarity >= threshold and idx < len(self.employee_face_mapping):
                emp, face_idx = self.employee_face_mapping[idx]
                results.append({
                    'employee': emp,
                    'face_index': face_idx,
                    'similarity': float(similarity),
                    'rank': i + 1
                })
        
        return results


def on_first_client_connect():
    """Called when first client connects"""
    global detection_thread
    print("🔌 First client connected - Starting webcam detection")
    if start_webcam_detection():
        if detection_thread is None or not detection_thread.is_alive():
            detection_thread = threading.Thread(target=detection_loop, daemon=True)
            detection_thread.start()
            print("🎯 Detection thread started")

def on_last_client_disconnect():
    """Called when last client disconnects"""
    print("🔌 All clients disconnected - Stopping webcam detection")
    stop_webcam_detection()

class ConsoleProgress:
    """Thay ProgressWindow khi headless: cùng interface, in ra console."""
    def __init__(self):
        self._max = 0

    def update_status(self, status_text, progress_value=None, progress_text="", detail_text=""):
        parts = [status_text]
        if progress_text:
            parts.append(progress_text)
        if detail_text:
            parts.append(detail_text)
        print("[TIẾN TRÌNH] " + " | ".join(parts))

    def set_progress_max(self, max_value):
        self._max = max_value

    def close_window(self):
        pass


class ProgressWindow:
    def __init__(self):
        # Lazy import: python3-tk không có trên Linux tối giản — chỉ import khi thật sự mở GUI
        import tkinter as tk
        from tkinter import ttk
        self.root = tk.Tk()
        self.root.title("Xử lý dữ liệu nhân viên")
        self.root.geometry("550x250")
        self.root.resizable(False, False)
        
        # Center the window on screen
        self.root.eval('tk::PlaceWindow . center')
        
        # Main frame
        main_frame = ttk.Frame(self.root, padding="20")
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Title label
        self.title_label = ttk.Label(main_frame, text="Đang xử lý dữ liệu khuôn mặt nhân viên", 
                                    font=('Arial', 12, 'bold'))
        self.title_label.grid(row=0, column=0, columnspan=2, pady=(0, 20))
        
        # Status label
        self.status_label = ttk.Label(main_frame, text="Đang khởi tạo...", 
                                     font=('Arial', 10))
        self.status_label.grid(row=1, column=0, columnspan=2, pady=(0, 10))
        
        # Progress bar
        self.progress = ttk.Progressbar(main_frame, mode='determinate', length=450)
        self.progress.grid(row=2, column=0, columnspan=2, pady=(0, 10))
        
        # Progress label
        self.progress_label = ttk.Label(main_frame, text="0/0", 
                                       font=('Arial', 9))
        self.progress_label.grid(row=3, column=0, columnspan=2)
        
        # Detail label
        self.detail_label = ttk.Label(main_frame, text="", 
                                     font=('Arial', 8), foreground='gray')
        self.detail_label.grid(row=4, column=0, columnspan=2, pady=(10, 0))
        
        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)
        
    def update_status(self, status_text, progress_value=None, progress_text="", detail_text=""):
        self.status_label.config(text=status_text)
        if progress_value is not None:
            self.progress['value'] = progress_value
        if progress_text:
            self.progress_label.config(text=progress_text)
        if detail_text:
            self.detail_label.config(text=detail_text)
        self.root.update()
        
    def set_progress_max(self, max_value):
        self.progress['maximum'] = max_value
        
    def close_window(self):
        self.root.quit()
        self.root.destroy()
        
    def on_closing(self):
        # Prevent manual closing during processing
        pass

def process_employees_with_progress():
    """Process employees with a progress UI (Tk window, or console when headless)"""
    if HEADLESS:
        progress_window = ConsoleProgress()
    else:
        try:
            progress_window = ProgressWindow()
        except Exception as e:
            print(f"⚠️ Không mở được cửa sổ tiến trình ({e}), chuyển sang console")
            progress_window = ConsoleProgress()

    try:
        # Load existing employee data from JSON files
        progress_window.update_status("Đang tải dữ liệu nhân viên hiện có...", 0)
        EmployeeList = load_employees_from_json()
        processed_urls = get_processed_urls(EmployeeList)
        
        progress_window.update_status(
            f"Đã tải {len(EmployeeList)} nhân viên",
            detail_text=f"Tìm thấy {len(processed_urls)} ảnh khuôn mặt đã xử lý"
        )
        time.sleep(1)  # Brief pause to show status
        
        # Get employees that need processing
        if df.empty or "ImgFaceDetection" not in df.columns:
            print("⚠️ Không có dữ liệu nhân viên từ API — chỉ dùng cache employees_data hiện có")
            df_filtered = pd.DataFrame()
        else:
            df_filtered = df.query("ImgFaceDetection.notna()")
        total_employees = len(df_filtered)
        
        if total_employees == 0:
            progress_window.update_status("Không tìm thấy nhân viên cần xử lý", 100)
            time.sleep(2)
            progress_window.close_window()
            return EmployeeList
        
        progress_window.set_progress_max(total_employees)
        progress_window.update_status(
            f"Đang xử lý {total_employees} nhân viên...",
            0,
            f"0/{total_employees}"
        )
        
        processed_count = 0
        
        for idx, (_, row) in enumerate(df_filtered.iterrows()):
            if not running:
                print("🛑 Nhận tín hiệu dừng — ngắt xử lý dữ liệu nhân viên")
                break
            uid = row["Ma"]
            name = row["FullName"]
            
            progress_window.update_status(
                f"Đang xử lý nhân viên: {name}",
                idx,
                f"{idx}/{total_employees}",
                f"UID: {uid}"
            )
            
            # Find existing employee or create new one
            em = find_employee_by_uid(EmployeeList, uid)
            if em is None:
                em = Employee(uid, name)
                EmployeeList.append(em)
                print(f"Created new employee: {name}")
            else:
                print(f"Found existing employee: {name}")
            
            imageUrls = row['ImgFaceDetection'].replace(
                "https://file.honghunghospital.com.vn",
                "http://172.16.28.109:9824"
            ).replace(
                "https://file.hungduy.vn",
                "http://172.16.10.4:5001"
            )
            images = [x.strip() for x in imageUrls.split(";") if x.strip()]
            
            new_images_processed = 0
            total_images = len(images)
            
            for img_idx, img_url in enumerate(images):
                progress_window.update_status(
                    f"Đang xử lý {name} - Ảnh {img_idx + 1}/{total_images}",
                    idx + (img_idx / total_images),
                    f"{idx}/{total_employees}",
                    f"Đang xử lý ảnh khuôn mặt..."
                )
                
                # Skip if URL already processed
                if img_url in processed_urls:
                    print(f"Skipping already processed image: {img_url}")
                    continue
                    
                try:
                    print(f"Processing NEW image for {name} from URL: {img_url}")
                    resp = requests.get(img_url, timeout=5)
                    if resp.status_code == 200:
                        nparr = np.frombuffer(resp.content, np.uint8)
                        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
                        img = cv2.copyMakeBorder(img, 200, 200, 200, 200, cv2.BORDER_CONSTANT, value=[0, 0, 0])
                        encode = img_to_vec(img)
                        if encode is not None:
                            em.appendEncode(Face(url=img_url, embedding=encode))
                            processed_urls.add(img_url)
                            new_images_processed += 1
                            print(f"Added new encoding for {name}")
                        else:
                            print(f"Failed to get encoding for image from URL: {img_url}")
                    else:
                        print(f"Failed to download image from URL: {img_url}, status code: {resp.status_code}")
                except Exception as e:
                    print(f"Error processing image from URL: {img_url}, error: {str(e)}")
            
            # Save updated employee data
            if new_images_processed > 0 or len(em.face) > 0:
                save_employee(em, uid)
                print(f"Employee {name} processed with {len(em.face)} total face encodings ({new_images_processed} new).")
            else:
                print(f"No face encodings for employee {name}")
            
            processed_count += 1
            progress_window.update_status(
                f"Hoàn thành: {name}",
                processed_count,
                f"{processed_count}/{total_employees}",
                f"Đã thêm {new_images_processed} mã hóa khuôn mặt mới"
            )
        
        # Final status
        progress_window.update_status(
            "Xử lý hoàn tất!",
            total_employees,
            f"{total_employees}/{total_employees}",
            f"Tổng số nhân viên: {len(EmployeeList)}, Ảnh khuôn mặt: {len(processed_urls)}"
        )
        
        time.sleep(2)  # Show completion message for 2 seconds
        
    except Exception as e:
        progress_window.update_status(
            f"Lỗi xảy ra: {str(e)}",
            detail_text="Dừng xử lý do có lỗi"
        )
        print(f"Error in process_employees_with_progress: {str(e)}")
        time.sleep(3)
    finally:
        progress_window.close_window()
    
    return EmployeeList

if __name__ == "__main__":
    # Set up signal handlers for graceful shutdown
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    print(f"🚀 Starting Face Recognition Server...")
    print("📡 Server will start webcam detection when clients connect")
    print("⏹️  Press Ctrl+C to stop the application")

    detection_thread = None

    inference_face_rec_callback_fn = partial(
        inference_callback_face_rec, output_queue=output_queue_face_rec
    )
    hailo_inference_face_rec_detect = HailoAsyncInference(
            face_recognition_model, output_queue_face, inference_face_rec_callback_fn,
            1, send_original_frame=True, output_type="FLOAT32")
    threading.Thread(target=hailo_inference_face_rec_detect.run, daemon=True).start()

    inference_face_callback_fn = partial(
        inference_callback_face, output_queue=output_queue_face
    )
    hailo_inference_face_detect = HailoAsyncInference(
            face_detector_model, input_queue_face, inference_face_callback_fn,
            1, send_original_frame=True)
    threading.Thread(target=hailo_inference_face_detect.run, daemon=True).start()

    # Initialize database directory
    os.makedirs(BASE_DIR, exist_ok=True)

    # Lấy dữ liệu nhân viên (đã chuyển ra khỏi import-time, có retry)
    print("🌐 Đang lấy dữ liệu nhân viên từ API...")
    df = fetch_employees_with_retry()

    # REFRESH_EMPLOYEES=0: bỏ qua bước tải/embed ảnh, chỉ nạp cache JSON
    if os.environ.get("REFRESH_EMPLOYEES", "1").strip() not in ("0", "false", "False"):
        print("Bắt đầu xử lý dữ liệu nhân viên...")
        EmployeeList = process_employees_with_progress()
    else:
        print("Loading existing employee data from JSON files...")
        EmployeeList = load_employees_from_json()
    processed_urls = get_processed_urls(EmployeeList)

    if not EmployeeList:
        print("=" * 60)
        print("❌ CẢNH BÁO: 0 nhân viên (API không trả dữ liệu và không có cache)")
        print("   Server vẫn chạy nhưng sẽ KHÔNG nhận diện được ai.")
        print("=" * 60)
    
    print(f"Processing complete. Total employees: {len(EmployeeList)}")
    print(f"Total processed face images: {len(processed_urls)}")
    
    # Build FAISS index for face recognition
    print("🔍 Building FAISS index for face recognition...")
    face_search_index = FaceSearchIndex()
    face_search_index.build_index(EmployeeList)
    print("✅ Face recognition index ready")
    
    # Initialize WebSocket server after processing is complete
    print("🚀 Starting WebSocket server...")
    
    # Initialize WebSocket server for web clients
    websocket_thread = initialize_websocket_server('0.0.0.0', 8765)
    set_websocket_callbacks(on_first_client_connect, on_last_client_disconnect)
    print("🌐 WebSocket server started on port 8765")
    
    print("\n" + "="*60)
    print("🎯 FACE RECOGNITION SERVER READY")
    print("="*60)
    print("🌐 WebSocket Server: localhost:8765") 
    print("👥 Employees in database:", len(EmployeeList))
    print("🔍 Face encodings ready:", len(processed_urls))
    print("\n⏳ Waiting for client connections to start detection...")
    print("🔌 Connect a client to begin webcam and face detection")
    print("="*60)
    
    # Keep the main thread alive
    try:
        while running:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n🛑 Keyboard interrupt received")

    # Cleanup
    print("🧹 Cleaning up...")
    stop_webcam_detection()
    print("✅ Application stopped successfully")


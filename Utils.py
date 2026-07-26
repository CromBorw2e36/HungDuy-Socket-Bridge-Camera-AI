import numpy as np
from PIL import Image
import cv2


def default_preprocessv2(image: np.ndarray, model_w: int, model_h: int) -> np.ndarray:
    """
    Preprocess image for model input using PIL resize instead of cv2.resize.
    
    Args:
        image: Input RGB image (H, W, 3) as numpy array
        model_w: Target model input width
        model_h: Target model input height
        
    Returns:
        Preprocessed padded image (model_h, model_w, 3) as numpy array
    """
    img_h, img_w = image.shape[:2]
    scale = min(model_w / img_w, model_h / img_h)
    new_img_w, new_img_h = int(img_w * scale), int(img_h * scale)

    # Choose filter adaptively
    pil_img = Image.fromarray(image)
    if scale < 1:  # downscaling
        pil_resized = pil_img.resize((new_img_w, new_img_h), Image.LANCZOS)
    else:  # upscaling
        pil_resized = pil_img.resize((new_img_w, new_img_h), Image.BICUBIC)

    resized_image = np.array(pil_resized)

    # Create padded image
    padded_image = np.full((model_h, model_w, 3), 114, dtype=np.uint8)
    x_offset = (model_w - new_img_w) // 2
    y_offset = (model_h - new_img_h) // 2
    padded_image[y_offset:y_offset + new_img_h, x_offset:x_offset + new_img_w] = resized_image

    return padded_image
    
def cosine_similarity(a, b):
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))

def get_similarity_transform(src_pts, dst_pts):
    """
    Calculate similarity transformation matrix for face alignment.
    
    Args:
        src_pts: Source landmarks (5 points) as numpy array of shape (5, 2)
        dst_pts: Target landmarks (5 points) as numpy array of shape (5, 2)
        
    Returns:
        2x3 transformation matrix
    """
    # Convert to homogeneous coordinates
    src_h = np.hstack([src_pts, np.ones((src_pts.shape[0], 1))])
    
    # Build the system of equations Ax = b
    # For similarity transform, we have 4 parameters: scale*cos(θ), -scale*sin(θ), tx, ty
    A = []
    b = []
    
    for i in range(src_pts.shape[0]):
        x, y = src_pts[i]
        u, v = dst_pts[i]
        
        # Equation for x-coordinate: ax - by + tx = u
        A.append([x, -y, 1, 0])
        b.append(u)
        
        # Equation for y-coordinate: bx + ay + ty = v  
        A.append([y, x, 0, 1])
        b.append(v)
    
    A = np.array(A)
    b = np.array(b)
    
    # Solve the least squares problem
    params = np.linalg.lstsq(A, b, rcond=None)[0]
    
    # Extract parameters
    a, b_param, tx, ty = params
    
    # Build transformation matrix
    transform_matrix = np.array([
        [a, -b_param, tx],
        [b_param, a, ty]
    ])
    
    return transform_matrix


def align_face(image, landmarks, target_size=(112, 112)):
    """
    Align face using 5-point landmarks for ArcFace input.
    
    Args:
        image: Input image as numpy array
        landmarks: 5 facial landmarks as numpy array of shape (5, 2)
                  Order: left_eye, right_eye, nose, left_mouth, right_mouth
        target_size: Target size for aligned face (width, height)
        
    Returns:
        Aligned face image as numpy array
    """
    # Standard 5-point landmarks for target face (normalized to target_size)
    # These are the ideal landmark positions for a frontal face
    w, h = target_size
    
    # Standard landmark template for 112x112 face (ArcFace standard)
    if target_size == (112, 112):
        dst_landmarks = np.array([
            [38.2946, 51.6963],  # left eye
            [73.5318, 51.5014],  # right eye  
            [56.0252, 71.7366],  # nose tip
            [41.5493, 92.3655],  # left mouth corner
            [70.7299, 92.2041]   # right mouth corner
        ], dtype=np.float32)
    else:
        # Scale the standard template to target size
        scale_x = w / 112.0
        scale_y = h / 112.0
        dst_landmarks = np.array([
            [38.2946 * scale_x, 51.6963 * scale_y],  # left eye
            [73.5318 * scale_x, 51.5014 * scale_y],  # right eye  
            [56.0252 * scale_x, 71.7366 * scale_y],  # nose tip
            [41.5493 * scale_x, 92.3655 * scale_y],  # left mouth corner
            [70.7299 * scale_x, 92.2041 * scale_y]   # right mouth corner
        ], dtype=np.float32)
    
    # Ensure landmarks are in the right format
    src_landmarks = np.array(landmarks, dtype=np.float32)
    if src_landmarks.shape[0] != 5:
        raise ValueError("Need exactly 5 landmarks for face alignment")
    
    # Calculate similarity transformation
    transform_matrix = get_similarity_transform(src_landmarks, dst_landmarks)
    
    # Apply transformation to align the face
    aligned_face = cv2.warpAffine(image, transform_matrix, target_size, 
                                 flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, 
                                 borderValue=0)
    
    return aligned_face


def preprocess_for_arcface(aligned_face):
    """
    Preprocess aligned face for ArcFace model input.
    
    Args:
        aligned_face: Aligned face image as numpy array (H, W, C)
        
    Returns:
        Preprocessed face ready for ArcFace model
    """
    # Convert BGR to RGB if needed
    if aligned_face.shape[2] == 3:
        # Assuming input is BGR (OpenCV format), convert to RGB
        aligned_face_rgb = cv2.cvtColor(aligned_face, cv2.COLOR_BGR2RGB)
    else:
        aligned_face_rgb = aligned_face
    
    # Normalize to [-1, 1] range (standard for ArcFace)
    preprocessed = (aligned_face_rgb.astype(np.float32) - 127.5) / 127.5
    
    return preprocessed


def rescale_network_outputs(outputs):
    """Rescale network outputs from quantized to float values"""
    # For SCRFD 10g, we expect 9 outputs: 3 levels × 3 outputs per level
    # The outputs should be ordered as: bbox, cls, landmarks for each level
    
    rescaled_outputs = []
    
    # Define the correct order for SCRFD outputs
    output_order = [
        "scrfd_10g/conv43",  # bbox level 1 
        "scrfd_10g/conv42",  # cls level 1
        "scrfd_10g/conv41",  # landmarks level 1
        "scrfd_10g/conv50",  # bbox level 2
        "scrfd_10g/conv49",  # cls level 2
        "scrfd_10g/conv51",  # landmarks level 2
        "scrfd_10g/conv57",  # bbox level 3
        "scrfd_10g/conv56",  # cls level 3
        "scrfd_10g/conv58"   # landmarks level 3
    ]
    
    for output_name in output_order:
        if output_name in outputs[0]:
            output = outputs[0][output_name].astype(np.float32)
            
            # Apply dequantization based on output type
            if "conv43" in output_name or "conv50" in output_name or "conv57" in output_name:
                # Box outputs - apply scale factor
                rescaled_outputs.append(output / 32.0)
            elif "conv42" in output_name or "conv49" in output_name or "conv56" in output_name:
                # Class outputs - normalize to [0,1]
                rescaled_outputs.append(output / 255.0)
            else:
                # Landmark outputs - apply zero point and scale
                rescaled_outputs.append((output - 113) / 29.0)
    
    return rescaled_outputs


def postprocess_scrfd_outputs(rescaled_outputs, input_shape, score_threshold=0.5, nms_threshold=0.4):
    """
    SCRFD postprocessing based on HailoDetectionScrfd.py implementation
    """
    try:
        # Debug: Print output shapes
        #print(f"Number of rescaled outputs: {len(rescaled_outputs)}")
        #for i, output in enumerate(rescaled_outputs):
        #    print(f"Output {i} shape: {output.shape}")
        
        # Configuration
        strides = [8, 16, 32]
        min_sizes = [[16, 32], [64, 128], [256, 512]]
        image_width, image_height = input_shape
        
        # Generate anchors
        def generate_anchors(min_sizes, strides, image_width, image_height):
            anchors = []
            for stride, min_size in zip(strides, min_sizes):
                height, width = image_height // stride, image_width // stride
                num_anchors = len(min_size)
                
                # Create center coordinates
                centers = np.stack(np.mgrid[:height, :width][::-1], axis=-1).astype(np.float32)
                centers = (centers * stride).reshape((-1, 2))
                centers[:, 0] /= image_width
                centers[:, 1] /= image_height
                
                if num_anchors > 1:
                    centers = np.stack([centers] * num_anchors, axis=1).reshape((-1, 2))
                
                scales = np.ones_like(centers, dtype=np.float32) * stride
                scales[:, 0] /= image_width
                scales[:, 1] /= image_height
                
                anchors.append(np.concatenate([centers, scales], axis=1))
            
            return np.concatenate(anchors, axis=0)
        
        # Collect predictions for boxes, classes, and landmarks
        def collect_predictions(outputs, num_branches=3):
            box_preds, class_preds, landmark_preds = [], [], []
            num_outputs = len(outputs)
            
            for i in range(0, num_outputs, num_branches):
                # Get the actual shapes and reshape accordingly
                box_output = outputs[i]
                class_output = outputs[i + 1] 
                landmark_output = outputs[i + 2]
                
                # For SCRFD, each level has different feature map sizes
                # Level 1: 80x80, Level 2: 40x40, Level 3: 20x20 for 640x640 input
                
                # Determine the feature map size from the output shape
                total_elements = box_output.size
                feature_map_size = total_elements // 4  # 4 coordinates per box
                num_anchors = 2  # 2 anchors per level for SCRFD
                
                # Reshape to (1, num_predictions, channels)
                box_pred = box_output.reshape(1, -1, 4)
                class_pred = class_output.reshape(1, -1, 1)  
                landmark_pred = landmark_output.reshape(1, -1, 10)
                
                box_preds.append(box_pred)
                class_preds.append(class_pred)
                landmark_preds.append(landmark_pred)
            
            # Concatenate all levels
            box_preds = np.concatenate(box_preds, axis=1)
            class_preds = np.concatenate(class_preds, axis=1)
            landmark_preds = np.concatenate(landmark_preds, axis=1)
            
            return box_preds, class_preds, landmark_preds
        
        # Decode bounding boxes
        def decode_boxes(box_detections, anchors, image_width, image_height):
            x1 = anchors[:, 0] - box_detections[:, 0] * anchors[:, 2]
            y1 = anchors[:, 1] - box_detections[:, 1] * anchors[:, 3]
            x2 = anchors[:, 0] + box_detections[:, 2] * anchors[:, 2]
            y2 = anchors[:, 1] + box_detections[:, 3] * anchors[:, 3]
            
            # Scale to image size
            x1 *= image_width
            y1 *= image_height
            x2 *= image_width
            y2 *= image_height
            
            return np.stack([x1, y1, x2, y2], axis=-1)
        
        # Decode landmarks
        def decode_landmarks(landmark_detections, anchors, image_width, image_height):
            predictions = []
            for i in range(0, 10, 2):  # 5 landmarks × 2 coordinates
                px = anchors[:, 0] + landmark_detections[:, i] * anchors[:, 2]
                py = anchors[:, 1] + landmark_detections[:, i + 1] * anchors[:, 3]
                
                # Scale to image size
                px *= image_width
                py *= image_height
                
                predictions.extend([px, py])
            
            return np.stack(predictions, axis=-1)
        
        # NMS implementation
        def nms(boxes, scores, threshold):
            if len(boxes) == 0:
                return []
            
            x1, y1, x2, y2 = boxes[:, 0], boxes[:, 1], boxes[:, 2], boxes[:, 3]
            areas = (x2 - x1) * (y2 - y1)
            order = scores.argsort()[::-1]
            
            keep = []
            while order.size > 0:
                i = order[0]
                keep.append(i)
                
                xx1 = np.maximum(x1[i], x1[order[1:]])
                yy1 = np.maximum(y1[i], y1[order[1:]])
                xx2 = np.minimum(x2[i], x2[order[1:]])
                yy2 = np.minimum(y2[i], y2[order[1:]])
                
                inter_area = np.maximum(0, xx2 - xx1) * np.maximum(0, yy2 - yy1)
                union_area = areas[i] + areas[order[1:]] - inter_area
                iou = inter_area / union_area
                
                order = order[1:][iou <= threshold]
            
            return keep
        
        # Generate anchors
        anchors = generate_anchors(min_sizes, strides, image_width, image_height)
        
        # Process outputs level by level instead of trying to concatenate mismatched shapes
        all_boxes = []
        all_scores = []
        all_landmarks = []
        
        anchor_offset = 0
        
        for level in range(3):  # 3 levels
            bbox_idx = level * 3
            cls_idx = level * 3 + 1
            landmark_idx = level * 3 + 2
            
            if bbox_idx >= len(rescaled_outputs):
                continue
                
            # Get outputs for this level
            bbox_output = rescaled_outputs[bbox_idx]
            cls_output = rescaled_outputs[cls_idx]
            landmark_output = rescaled_outputs[landmark_idx]
            
            # Calculate feature map size for this level
            stride = strides[level]
            feature_h = image_height // stride
            feature_w = image_width // stride
            num_anchors = len(min_sizes[level])
            total_anchors = feature_h * feature_w * num_anchors
            
            # Get anchors for this level
            level_anchors = anchors[anchor_offset:anchor_offset + total_anchors]
            anchor_offset += total_anchors
            
            # Reshape outputs to match expected format
            bbox_reshaped = bbox_output.reshape(-1, 4)
            cls_reshaped = cls_output.reshape(-1, 1)
            landmark_reshaped = landmark_output.reshape(-1, 10)
            
            # Make sure shapes match
            min_size = min(len(bbox_reshaped), len(cls_reshaped), len(landmark_reshaped), len(level_anchors))
            
            if min_size > 0:
                bbox_level = bbox_reshaped[:min_size]
                cls_level = cls_reshaped[:min_size]
                landmark_level = landmark_reshaped[:min_size]
                anchors_level = level_anchors[:min_size]
                
                # Decode boxes
                decoded_boxes = decode_boxes(bbox_level, anchors_level, image_width, image_height)
                decoded_landmarks = decode_landmarks(landmark_level, anchors_level, image_width, image_height)
                
                all_boxes.append(decoded_boxes)
                all_scores.append(cls_level.squeeze(-1))
                all_landmarks.append(decoded_landmarks)
        
        if not all_boxes:
            return {
                'detection_boxes': [[]],
                'detection_scores': [[]],
                'face_landmarks': [[]]
            }
        
        # Concatenate all levels
        final_boxes = np.concatenate(all_boxes, axis=0)
        final_scores = np.concatenate(all_scores, axis=0)
        final_landmarks = np.concatenate(all_landmarks, axis=0)
        
        # Filter by score threshold
        mask = final_scores >= score_threshold
        filtered_boxes = final_boxes[mask]
        filtered_scores = final_scores[mask]
        filtered_landmarks = final_landmarks[mask]
        
        if len(filtered_boxes) == 0:
            return {
                'detection_boxes': [[]],
                'detection_scores': [[]],
                'face_landmarks': [[]]
            }
        
        # Apply NMS
        keep_indices = nms(filtered_boxes, filtered_scores, nms_threshold)
        nms_boxes = filtered_boxes[keep_indices]
        nms_scores = filtered_scores[keep_indices]
        nms_landmarks = filtered_landmarks[keep_indices]
        
        # Normalize coordinates to [0, 1]
        nms_boxes[:, [0, 2]] /= image_width   # x coordinates
        nms_boxes[:, [1, 3]] /= image_height  # y coordinates
        
        nms_landmarks[:, 0::2] /= image_width   # x coordinates
        nms_landmarks[:, 1::2] /= image_height  # y coordinates
        
        return {
            'detection_boxes': [nms_boxes.tolist()],
            'detection_scores': [nms_scores.tolist()],
            'face_landmarks': [nms_landmarks.tolist()]
        }
        
    except Exception as e:
        print(f"Error in postprocessing: {str(e)}")
        return {
            'detection_boxes': [[]],
            'detection_scores': [[]],
            'face_landmarks': [[]]
        }

def plot_boxes_on_image(image, results, original_size=None, model_size=(640, 640)):
    """Plot detection boxes and facial landmarks on the image."""
    image_with_boxes = image.copy()
    height, width = image.shape[:2]
    
    if 'detection_boxes' not in results or len(results['detection_boxes']) == 0:
        return image_with_boxes
    
    # Get first item in batch
    boxes = results['detection_boxes'][0]
    scores = results['detection_scores'][0]
    
    # Check if landmarks exist
    landmarks = results.get('face_landmarks', [[]])[0] if 'face_landmarks' in results else []
    # If original_size is provided, we need to transform coordinates back to original image space
    if original_size is not None:
        orig_height, orig_width = original_size
        model_width, model_height = model_size
        
        # Calculate the scale and offsets used in preprocessing
        scale = min(model_width / orig_width, model_height / orig_height)
        new_width, new_height = int(orig_width * scale), int(orig_height * scale)
        x_offset = (model_width - new_width) // 2
        y_offset = (model_height - new_height) // 2
        
        # Transform coordinates back to original image space
        transformed_boxes = []
        for box in boxes:
            x1, y1, x2, y2 = box
            # Convert from normalized [0,1] to model coordinates
            x1_model = x1 * model_width
            y1_model = y1 * model_height
            x2_model = x2 * model_width
            y2_model = y2 * model_height
            
            # Remove padding offset
            x1_scaled = x1_model - x_offset
            y1_scaled = y1_model - y_offset
            x2_scaled = x2_model - x_offset
            y2_scaled = y2_model - y_offset
            
            # Scale back to original image
            x1_orig = x1_scaled / scale
            y1_orig = y1_scaled / scale
            x2_orig = x2_scaled / scale
            y2_orig = y2_scaled / scale
            
            # Normalize to original image size
            x1_norm = x1_orig / orig_width
            y1_norm = y1_orig / orig_height
            x2_norm = x2_orig / orig_width
            y2_norm = y2_orig / orig_height
            
            transformed_boxes.append([x1_norm, y1_norm, x2_norm, y2_norm])
        
        boxes = transformed_boxes
        
        # Also transform landmarks if available
        if landmarks and original_size is not None:
            transformed_landmarks = []
            for landmark_set in landmarks:
                transformed_landmark_set = []
                for j in range(0, len(landmark_set), 2):
                    x_model = landmark_set[j] * model_width
                    y_model = landmark_set[j + 1] * model_height
                    
                    # Remove padding offset
                    x_scaled = x_model - x_offset
                    y_scaled = y_model - y_offset
                    
                    # Scale back to original image
                    x_orig = x_scaled / scale
                    y_orig = y_scaled / scale
                    
                    # Normalize to original image size
                    x_norm = x_orig / orig_width
                    y_norm = y_orig / orig_height
                    
                    transformed_landmark_set.extend([x_norm, y_norm])
                
                transformed_landmarks.append(transformed_landmark_set)
            
            landmarks = transformed_landmarks
            
    # Draw each box and its landmarks
    img_for_arc = []  # List to store aligned faces for ArcFace
    
    for i, (box, score) in enumerate(zip(boxes, scores)):
        # Draw bounding box
        x1, y1, x2, y2 = box
        x1, x2 = int(x1 * width), int(x2 * width)
        y1, y2 = int(y1 * height), int(y2 * height)
        cv2.rectangle(image_with_boxes, (x1, y1), (x2, y2), (0, 255, 0), 2)
        
        # Draw score
        score_text = f"Score: {score:.2f}"
        cv2.putText(image_with_boxes, score_text, (x1, y1-10), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)
        
        # Draw landmarks if available and extract aligned face
        if len(landmarks) > i and len(landmarks[i]) >= 10:  # 5 landmarks * 2 coordinates
            landmarks_points = landmarks[i]
            
            # Convert landmarks to pixel coordinates and reshape for face alignment
            face_landmarks = []
            for j in range(0, len(landmarks_points), 2):
                x = landmarks_points[j] * width
                y = landmarks_points[j + 1] * height
                face_landmarks.append([x, y])
                
                # Draw landmark points
                cv2.circle(image_with_boxes, (int(x), int(y)), 2, (0, 0, 255), -1)
            
            # Extract aligned face for ArcFace if we have 5 landmarks
            if len(face_landmarks) == 5:
                try:
                    face_landmarks_array = np.array(face_landmarks, dtype=np.float32)
                    aligned_face = align_face(image, face_landmarks_array, target_size=(112, 112))
                    preprocessed_face = preprocess_for_arcface(aligned_face)
                    img_for_arc.append({
                        'aligned_face': aligned_face,
                        'preprocessed_face': preprocessed_face,
                        'landmarks': face_landmarks_array,
                        'bbox': [x1, y1, x2, y2],
                        'score': score
                    })
                except Exception as e:
                    print(f"Failed to align face {i}: {str(e)}")
                    continue


    return image_with_boxes, img_for_arc, landmarks, boxes


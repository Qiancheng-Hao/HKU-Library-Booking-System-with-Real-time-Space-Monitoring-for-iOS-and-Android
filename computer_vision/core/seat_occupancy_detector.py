import cv2
import numpy as np
from ultralytics import YOLO
from typing import Dict, List, Tuple
import json
from pathlib import Path
import torch
import os 
import logging
import time

class SeatOccupancyDetector:
    """
    Seat Occupancy Detector, main class handlingg occupancy detection. 
    """
    def __init__(self, occupancy_model_path: str, seat_model_path: str, debug_mode: bool = False, device: str = 'auto') -> None:
        """
        Initialize the SeatOccupancyDetector with two models.
        Args:
            occupancy_model_path (str): Occupancy model path ('person', 'hogging_item')
            seat_model_path (str): Seat model path ('seat')
            debug_mode (bool): Whether to enable debug mode
            device (str): Device to run on ('auto', 'cpu', 'cuda', '0', etc.)
        """
        if device == 'auto':
            if torch.cuda.is_available():
                device = 'cuda'
            elif torch.backends.mps.is_available():
                device = 'mps'
            else:
                device = 'cpu'
        self.device = device
        self.debug_mode = debug_mode
        self.occupancy_model = YOLO(occupancy_model_path)
        self.seat_model = YOLO(seat_model_path)

        # Debug mode: Show model information
        if debug_mode:
            logging.info(f"--------------------")
            logging.info(f"All models loaded successfully! Running on: {self.device}")
            logging.info(f"\n--- Occupancy Model Information ({occupancy_model_path}) ---")
            logging.info(f"  - Classes: {self.occupancy_model.names}")
            logging.info(f"\n--- Seat Model Information ({seat_model_path}) ---")
            logging.info(f"  - Classes: {self.seat_model.names}")
            logging.info(f"--------------------") 

    def preprocess_image(self, image: np.ndarray) -> np.ndarray:
        """
        Image preprocessing function entrance \n
        It will first identify the current image quality, then apply suitable preprocessing techniques.
        Args:
            image (np.ndarray): Input image in BGR format
        Returns:
            np.ndarray: Preprocessed image
        """
        # !!! need to use more advanced preprocessing later !!!
        # can detect the image quality first and then decide which preprocessing to apply
        # call different preprocessing function for different scenarios (e.g., low light, glare, shadows, etc.)
        lab = cv2.cvtColor(image, cv2.COLOR_BGR2LAB)
        l, a, b = cv2.split(lab)
        clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8,8))
        l = clahe.apply(l)
        enhanced = cv2.merge([l, a, b])
        enhanced = cv2.cvtColor(enhanced, cv2.COLOR_LAB2BGR)
        return enhanced
    
    # Utility Functions
    @staticmethod 
    def get_box_center(box: List[float]) -> Tuple[float, float]:
        """Calculate the center point of a bounding box
        Args:
            box (List[float]): Bounding box in format [x1, y1, x2, y2]
        Returns:
            Tuple [float, float]: (center_x, center_y)
        """
        x1, y1, x2, y2 = box
        return (x1 + x2) / 2, (y1 + y2) / 2

    @staticmethod
    def get_distance(point1: Tuple[float, float], point2: Tuple[float, float]) -> float:
        """Calculate the Euclidean distance between two points
        Args:
            point1 (Tuple[float, float]): (x1, y1)
            point2 (Tuple[float, float]): (x2, y2)
        Returns:
            float: Euclidean distance
        """
        return np.sqrt((point1[0] - point2[0])**2 + (point1[1] - point2[1])**2)
    
    @staticmethod
    def calculate_iou(box1: List[float], box2: List[float]) -> float:
        """
        Calculate Intersection over Union (IoU) between two boxes. 
        IoU is a metric to measure the overlap between two bounding boxes.
        It is defined as: Area of Intersection / Area of Union
        Args:
            box1, box2: Bounding boxes in format [x1, y1, x2, y2]
                        where (x1, y1) is the top-left corner
                        and (x2, y2) is the bottom-right corner.
        Returns:
            IoU value, a float between 0.0 (no overlap) and 1.0 (perfect overlap)
        """
        # Unpack the coordinates for both boxes
        x1_1, y1_1, x2_1, y2_1 = box1 # left top (x1,y1) → right bottom (x2,y2)
        x1_2, y1_2, x2_2, y2_2 = box2 # same with above 
        
        # Calculate intersection area
        x1_i = max(x1_1, x1_2)  # Find the top-left corner (x1, y1) of the intersection area
        y1_i = max(y1_1, y1_2)  # Find the top-left corner (x1, y1) of the intersection area
        x2_i = min(x2_1, x2_2)  # Find the bottom-right corner (x2, y2) of the intersection area
        y2_i = min(y2_1, y2_2)  # Find the bottom-right corner (x2, y2) of the intersection area

        # Check if there is a valid intersection
        if x2_i < x1_i or y2_i < y1_i:
            return 0.0 # No overlap, IoU is 0
        
        # Calculate intersection area
        intersection = (x2_i - x1_i) * (y2_i - y1_i)
        
        # Calculate the area of each individual box
        area1 = (x2_1 - x1_1) * (y2_1 - y1_1)
        area2 = (x2_2 - x1_2) * (y2_2 - y1_2)
        
        # Calculate union area
        union = area1 + area2 - intersection
        return intersection / union if union > 0 else 0.0
    
    @staticmethod
    def is_point_in_box(point: Tuple[float, float], box: List[float], expansion_factor: float = 1.0) -> bool:
        """
        Check if a point is inside a bounding box (with optional expansion)
        Args:
            point: (x, y) coordinates
            box: Bounding box [x1, y1, x2, y2]
            expansion_factor: Factor to expand the box (1.0 = no expansion, 1.5 = 50% larger)
            
        Returns:
            True if point is inside the (expanded) box
        """
        x1, y1, x2, y2 = box
        
        # Expand box if needed
        if expansion_factor != 1.0:
            width = x2 - x1
            height = y2 - y1
            
            # Calculate how much to add/subtract from each side
            x_expand = width * (expansion_factor - 1.0) / 2
            y_expand = height * (expansion_factor - 1.0) / 2
            
            # Apply the expansion
            x1 -= x_expand  # Move left edge left
            x2 += x_expand  # Move right edge right
            y1 -= y_expand  # Move top edge up
            y2 += y_expand  # Move bottom edge down
            
        px, py = point
        return x1 <= px <= x2 and y1 <= py <= y2

    def cluster_items(self, item_boxes: List, item_cluster_threshold: float) -> List[List]:
        """
        Cluster items that are close together
        Args:
            item_boxes: List of item bounding boxes
            item_cluster_threshold: Distance threshold for clustering items together
        Returns:
            List of item clusters, where each cluster is a list of boxes
        """
        if len(item_boxes) == 0:
            return []
        
        # Initialize each item as its own cluster
        clusters = [[box] for box in item_boxes]
        
        # Iteratively merge clusters that are close together
        merged = True
        while merged:
            merged = False # Assume no merges this round
            new_clusters = []
            used = set() # Track which clusters have been merged
            for i in range(len(clusters)):
                # skip if already merged
                if i in used:
                    continue
                current_cluster = clusters[i]
                merged_cluster = current_cluster.copy()
                
                # Check if this cluster should merge with any other cluster
                for j in range(i + 1, len(clusters)):
                    if j in used:
                        continue
                    
                    # Check minimum distance between any items in the two clusters
                    min_distance = float('inf')
                    for box1 in current_cluster:
                        for box2 in clusters[j]:
                            dist = self.get_distance(
                                self.get_box_center(box1),
                                self.get_box_center(box2)
                            )
                            min_distance = min(min_distance, dist)
                    
                    # If clusters are close enough, merge them
                    if min_distance < item_cluster_threshold:
                        merged_cluster.extend(clusters[j])
                        used.add(j)
                        merged = True
                
                new_clusters.append(merged_cluster)
                used.add(i)
            
            # Update clusters for next iteration
            clusters = new_clusters
        
        if self.debug_mode:
            logging.info(f"  [Clustering] {len(item_boxes)} items -> {len(clusters)} clusters")
        
        return clusters
    
    # Spatial Filtering Function
    def filter_items_on_seats(self, item_boxes: List, seat_boxes: List, iou_threshold: float = 0.0, expansion_factor: float = 1.0) -> Tuple[List, List]:
        """
        Filter items based on whether they are on seats
        Args:
            item_boxes: List of item bounding boxes
            seat_boxes: List of seat bounding boxes
            iou_threshold: Minimum IoU to consider overlap (0.0 = any overlap)
            expansion_factor: Factor to expand seat boxes to cover desk area (1.0 = chair only, 1.5 = chair + surrounding desk area)
        
        Returns:
            Tuple of (items_on_seats, items_off_seats)
        """
        if len(seat_boxes) == 0:
            # No seats detected, return all items as off-seats
            return [], item_boxes
        
        items_on_seats = []
        items_off_seats = []
        
        for item_box in item_boxes:
            is_on_seat = False # Assume not on seat
            item_center = self.get_box_center(item_box)
            
            for seat_box in seat_boxes:
                # Method 1: Check if item overlaps with seat (using IoU)
                iou = self.calculate_iou(item_box, seat_box)
                if iou > iou_threshold:
                    is_on_seat = True
                    break
                
                # Method 2: Check if item center is within expanded seat area (This covers items on desk near the chair)
                if self.is_point_in_box(item_center, seat_box, expansion_factor):
                    is_on_seat = True
                    break
            
            if is_on_seat:
                items_on_seats.append(item_box)
            else:
                items_off_seats.append(item_box)
        
        if self.debug_mode:
            logging.info(f"  [Spatial Filter] On seats: {len(items_on_seats)} items")
            logging.info(f"  [Spatial Filter] Off seats: {len(items_off_seats)} items")
        
        return items_on_seats, items_off_seats

    def visualize_detections(
        self, 
        image: np.ndarray, 
        persons: List, 
        hogging_clusters: List[List],
        associated_items: List,
        ignored_clusters: List[List],
        seats: List,
        save_path: str = None,
        total_occupancy: int = 0
    ) -> np.ndarray:
        """
        Visualization (Occupancy Model)
        - Persons (Green)
        - Hogging Clusters (Red - Counted as Occupied)
        - Associated Items (Blue - Not Counted)
        - Ignored Clusters (Yellow - Off seats, Not Counted)
        - Seats (Cyan - Reference only)
        
        Returns:
            np.ndarray: Visualized image
        """
        vis_img = image.copy()
        
        colors = {
            'person': (0, 255, 0),         # Green
            'hogging': (0, 0, 255),        # Red (Counted as Occupied)
            'associated': (255, 0, 0),     # Blue (Not Counted)
            'ignored': (0, 255, 255),      # Yellow (Off seats)
            'seat': (255, 255, 0)          # Cyan (Reference)
        }
        
        # Draw seats first (background reference)
        for box in seats:
            x1, y1, x2, y2 = map(int, box)
            cv2.rectangle(vis_img, (x1, y1), (x2, y2), colors['seat'], 2)
            cv2.putText(vis_img, 'Seat', (x1, y1-5), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, colors['seat'], 2)
        
        # Draw ignored clusters (yellow)
        for cluster in ignored_clusters:
            for box in cluster:
                x1, y1, x2, y2 = map(int, box)
                cv2.rectangle(vis_img, (x1, y1), (x2, y2), colors['ignored'], 2)
                cv2.putText(vis_img, 'Item (Off Seat)', (x1, y1-5), 
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, colors['ignored'], 2)
        
        # Draw associated items (blue)
        for box in associated_items:
            x1, y1, x2, y2 = map(int, box)
            cv2.rectangle(vis_img, (x1, y1), (x2, y2), colors['associated'], 2)
            cv2.putText(vis_img, 'Item (With Person)', (x1, y1-5), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, colors['associated'], 2)

        # Draw hogging clusters (red)
        cluster_num = 1
        for cluster in hogging_clusters:
            for box in cluster:
                x1, y1, x2, y2 = map(int, box)
                cv2.rectangle(vis_img, (x1, y1), (x2, y2), colors['hogging'], 2)
                cv2.putText(vis_img, f'HOGGING #{cluster_num} ({len(cluster)} items)', 
                            (x1, y1-5), 
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, colors['hogging'], 2)
            cluster_num += 1
                            
        # Draw persons (green)
        for box in persons:
            x1, y1, x2, y2 = map(int, box)
            cv2.rectangle(vis_img, (x1, y1), (x2, y2), colors['person'], 2)
            cv2.putText(vis_img, 'PERSON', (x1, y1-5), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, colors['person'], 2)
        
        # Add statistics text
        total_hogging_items = sum(len(cluster) for cluster in hogging_clusters)
        total_ignored_items = sum(len(cluster) for cluster in ignored_clusters) if ignored_clusters else 0
        
        stats_text = [
            f"TOTAL OCCUPANCY: {total_occupancy}",
            "---",
            f"Persons: {len(persons)} (Occupied)",
            f"Hogging Regions: {len(hogging_clusters)} ({total_hogging_items} items on seats)",
            f"Associated Items: {len(associated_items)} (With persons)",
        ]
        
        if ignored_clusters:
            stats_text.append(f"Ignored Items: {total_ignored_items} (Off seats)")
        
        y_offset = 30
        for text in stats_text:
            # Outline for better visibility
            cv2.putText(vis_img, text, (10, y_offset), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 0), 3)
            cv2.putText(vis_img, text, (10, y_offset), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
            y_offset += 30
        
        # Only save to file if save_path is provided
        if save_path is not None:
            cv2.imwrite(save_path, vis_img)
            if self.debug_mode:
                logging.info(f" Visualization result saved to: {save_path}")
        
        return vis_img

    # Occupancy Detection with Seat Filtering
    def get_occupancy_stats_with_seats(
        self, 
        image: np.ndarray,
        person_class_id: int = 0,
        hogging_item_class_id: list = [
            24, # backpack
            25, # umbrella
            26, # handbag
            28, # suitcase
            39, # bottle
            41, # cup
            60, # book
            63, # laptop
            64, # mouse
            66, # keyboard
            73, # book 
            76  # cell phone
            ],
        seat_class_id: list = [56, 57],
        confidence_threshold: float = 0.5,
        proximity_threshold: float = 100.0,
        item_cluster_threshold: float = 150.0,
        seat_expansion_factor: float = 1.5,
        use_preprocessing: bool = False,
        visualize: bool = False,
        output_path: str = "detection_result.jpg",
        imgsz: int = 640,
        seat_imgsz: int = 640,
        location: str = "",
        area: str = ""
    ) -> Dict:
        """
        Function 1+ (Advanced): Analyze image with seat-based spatial filtering
        
        This method runs BOTH models in real-time:
        - Occupancy Model: Detects persons and items
        - Seat Model: Detects seat positions (for spatial filtering)
        
        Only items that are physically on/near seats are counted as hogging.
        
        Args:
            seat_expansion_factor: How much to expand seat bbox to cover desk area (1.0 = chair only, 1.5 = chair + desk, 2.0 = larger area)
            seat_imgsz: Image size for seat detection (can be smaller for speed)
            location: Location identifier for the image
            area: Area identifier within the location
        
        Returns:
            Dict with occupancy stats (only counting items on seats)
        """
        # Preprocessing (optional but strongly recommended)
        if use_preprocessing:
            if self.debug_mode: logging.info("Applying image preprocessing...")
            image = self.preprocess_image(image)
        
        # Run Occupancy Model (persons + items)
        if self.debug_mode: logging.info("Running Occupancy Model...")
        occupancy_results = self.occupancy_model(image, verbose=False, imgsz=imgsz, device=self.device)
        occupancy_detections = occupancy_results[0].boxes
        
        persons_boxes = []
        objects_boxes = []

        # Classify all detected person and items
        for det in occupancy_detections:
            conf = float(det.conf[0].cpu().numpy()) # det.conf = tensor([0.95], device='cuda:0')
            cls_id = int(det.cls[0].cpu().numpy())

            # Apply confidence threshold
            if conf < confidence_threshold:
                continue
                
            box = det.xyxy[0].cpu().numpy() # det.xyxy = tensor([[10.1, 20.2, 30.3, 40.4]], device='cuda:0')
            if cls_id == person_class_id:
                persons_boxes.append(box)
            elif cls_id in hogging_item_class_id:
                objects_boxes.append(box)

        # Run Seat Model (seats)
        seat_results = self.seat_model(image, verbose=False, imgsz=seat_imgsz, device=self.device)
        seat_detections = seat_results[0].boxes

        # Classify all detected seats
        seat_boxes = []
        for det in seat_detections:
            conf = float(det.conf[0].cpu().numpy())
            cls_id = int(det.cls[0].cpu().numpy())
            
            # Use same confidence threshold for seats
            if conf >= confidence_threshold and cls_id in seat_class_id:
                seat_boxes.append(det.xyxy[0].cpu().numpy())

        # Filter items associated with persons
        person_centers = [self.get_box_center(box) for box in persons_boxes]
        
        lone_items = [] # items not associated with persons
        associated_items = [] # items associated with persons

        
        for item_box in objects_boxes:
            is_associated = False # Assume not associated
            item_center = self.get_box_center(item_box)
            
            for person_center in person_centers:
                distance = self.get_distance(item_center, person_center)
                if distance < proximity_threshold:
                    is_associated = True
                    break
            
            if is_associated:
                associated_items.append(item_box)
            else:
                lone_items.append(item_box)
        
        # Filter lone items based on seat positions
        items_on_seats, items_off_seats = self.filter_items_on_seats(
            lone_items,
            seat_boxes,
            expansion_factor=seat_expansion_factor
        )
        
        # Cluster items that are on seats
        hogging_item_clusters = self.cluster_items(items_on_seats, item_cluster_threshold)
        
        # Calculate totals (only count items ON seats)
        person_count = len(persons_boxes)
        hogging_region_count = len(hogging_item_clusters)  # Only clusters on seats
        total_occupancy = person_count + hogging_region_count
        
        # Visualization (if needed)
        visualized_image = None
        if visualize:
            # Convert items_off_seats to cluster format (list of lists)
            ignored_clusters = [items_off_seats] if items_off_seats else []
            
            visualized_image = self.visualize_detections(
                image, 
                persons_boxes, 
                hogging_item_clusters,      # Red: Counted
                associated_items,       
                ignored_clusters=ignored_clusters,  # Yellow: Ignored
                seats=seat_boxes,       # Cyan: Reference
                save_path=output_path,
                total_occupancy=total_occupancy
            )

        # Return results
        stats = {
            "time_stamp": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()),
            "location": location,
            "area": area,
           # "total_occupancy": total_occupancy,
            "total_number_of_person": person_count,
            "total_number_of_hogging_items": hogging_region_count,
            #"total_lone_items_on_seats": len(items_on_seats),
            #"total_lone_items_off_seats": len(items_off_seats),
            #"items_ignored_off_seats": len(items_off_seats), # New stat for items filtered out
            #"hogging_item_count_associated": len(associated_items),
            #"total_items_detected": len(objects_boxes),
            "total_number_of_seats": len(seat_boxes),
            "occupancy_rate": min((person_count + hogging_region_count) / len(seat_boxes) if len(seat_boxes) > 0 else -1.0, 1.0),
            # "thresholds_used": {
            #     "confidence": confidence_threshold,
            #     "proximity_pixels": proximity_threshold,
            #     "item_cluster_pixels": item_cluster_threshold,
            #     "seat_expansion_factor": seat_expansion_factor,
            #     "image_size": imgsz,
            #     "seat_image_size": seat_imgz
            # }
        }
        
        if self.debug_mode:
            logging.info(f"  [Final Stats] Occupancy: {total_occupancy} = {person_count} persons + {hogging_region_count} hogging regions")
        
        # Return stats with optional visualized image
        if visualize:
            return {"stats": stats, "visualized_image": visualized_image}
        else:
            return stats

    def count_total_seats(
        self,
        image: np.ndarray,
        seat_class_id: list = [56, 57],
        confidence_threshold: float = 0.5,
        use_preprocessing: bool = False,
        visualize: bool = False,
        output_path: str = "total_seats_result.jpg",
        imgsz: int = 640
    ) -> Dict:
        """
        Usage: Count total seats 
        This Function uses self.seat_model
        
        Backend Usage:
        - Run once daily (e.g., 6 AM when facility is empty)
        - Store result as the region's total capacity
        """
        
        # Preprocessing (optional)
        if use_preprocessing:
            if self.debug_mode: print("  [Seat] Applying image preprocessing...")
            image = self.preprocess_image(image)

        # Run Seat Model
        results = self.seat_model(image, verbose=False, imgsz=imgsz, device=self.device)
        detections = results[0].boxes
        
        # Classify all detected seats
        seat_count = 0
        seat_boxes = []
        for det in detections:
            conf = float(det.conf[0].cpu().numpy())
            cls_id = int(det.cls[0].cpu().numpy())
            
            if conf >= confidence_threshold and cls_id in seat_class_id:
                seat_count += 1
                if visualize:
                    seat_boxes.append(det.xyxy[0].cpu().numpy())
        
        # Visualization (if needed)
        if visualize:
            vis_img = image.copy()
            for box in seat_boxes:
                x1, y1, x2, y2 = map(int, box)
                cv2.rectangle(vis_img, (x1, y1), (x2, y2), (0, 255, 0), 2)
                cv2.putText(vis_img, f'Seat', (x1, y1-5), 
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)
            
            text = f"TOTAL SEATS DETECTED: {seat_count}"
            cv2.putText(vis_img, text, (10, 30), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 0), 3)
            cv2.putText(vis_img, text, (10, 30), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
            
            cv2.imwrite(output_path, vis_img)
            if self.debug_mode:
                print(f"[Seat] Visualization saved: {output_path}")

        # Return results
        stats = {
            "total_seat_count": seat_count,
            # "confidence_threshold": confidence_threshold,
            # "image_size": imgsz
        }
        
        return stats
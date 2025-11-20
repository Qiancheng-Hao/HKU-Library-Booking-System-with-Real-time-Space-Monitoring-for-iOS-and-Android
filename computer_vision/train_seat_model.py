from ultralytics import YOLO
import torch
import os

if __name__ == "__main__":
    print(f"CUDA available: {torch.cuda.is_available()}")
    
    # Define the path to data.yaml file
    data_yaml_path = os.path.join(os.path.dirname(__file__), "Seat", "data.yaml")
    
    # Check if the file exists
    if not os.path.exists(data_yaml_path):
        print(f"Error: data.yaml file not found!")
        print(f"Please check the path: {data_yaml_path}")
    else:
        print(f"Successfully found data.yaml: {data_yaml_path}")

        # base model
        model = YOLO("yolo11x.pt") 

        # 3. Start training!
        print("--- Starting training of Seat Counter Model ---")
        results = model.train(
            data=data_yaml_path,
            epochs=100,         
            imgsz=640,         
            cache=False,
            device=0,          
            batch=8,           
            name="HKU_SeatCounter_v1"  
        )
        
        print("--- Training completed! ---")
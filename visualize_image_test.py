import cv2
import sys
from pathlib import Path

# 设置项目根目录以便导入
current_dir = Path(__file__).resolve().parent
project_root = current_dir
sys.path.insert(0, str(project_root))
# 将 backend 目录也加入路径，以便能找到 'app' 模块
sys.path.insert(0, str(project_root / "backend"))

from computer_vision.core.seat_occupancy_detector import SeatOccupancyDetector
# 直接导入时不再带 backend 前缀，因为我们已经把 backend 加入 path 了
from app.services.occupancy_cv_service import _resolve_model_paths

def visualize_image_test(image_path: str, output_image_path: str = "output_viz_image.jpg"):
    """
    运行 CV 模型并生成带有可视化结果的图片文件。
    """
    print(f"Start processing image: {image_path}")
    
    # 1. 准备模型
    try:
        occupancy_path, seat_path = _resolve_model_paths()
        print(f"Loading models from:\n  Occupancy: {occupancy_path}\n  Seat: {seat_path}")
        
        detector = SeatOccupancyDetector(
            occupancy_model_path=occupancy_path,
            seat_model_path=seat_path,
            debug_mode=True,
            device='auto'
        )
    except Exception as e:
        print(f"Failed to load models: {e}")
        return

    # 2. 读取图片
    if not Path(image_path).exists():
        print(f"Error: Image file not found at {image_path}")
        return
        
    img = cv2.imread(image_path)
    if img is None:
        print("Error: Could not read image file.")
        return

    print(f"Image Info: {img.shape[1]}x{img.shape[0]}")

    # 3. 运行推理并保存结果
    print("Running inference...")
    
    # get_occupancy_stats_with_seats 方法中，如果 visualize=True，
    # 它会自动将结果保存到 output_path 指定的文件中。
    result = detector.get_occupancy_stats_with_seats(
        img,
        visualize=True,
        output_path=output_image_path,
        # 可以根据需要调整以下阈值
        # confidence_threshold=0.25, 
        # seat_expansion_factor=1.5
        hogging_item_class_id=list(range(23)),
        person_class_id=23,
        seat_class_id=[56,57]
    )
    
    print("\nInference Stats:")
    print(result)
    print(f"\nVisualization saved to: {output_image_path}")

if __name__ == "__main__":
    # 默认测试图片路径
    default_img_path = str(Path(project_root) / "computer_vision" / "test" / "data" / "ChiWah" / "33.jpg")
    
    # 允许从命令行传入图片路径
    target_img = sys.argv[1] if len(sys.argv) > 1 else default_img_path
    
    visualize_image_test(target_img)

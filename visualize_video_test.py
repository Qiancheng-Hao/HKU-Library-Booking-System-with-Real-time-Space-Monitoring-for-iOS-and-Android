import cv2
import sys
from pathlib import Path
import time

# 设置项目根目录以便导入
current_dir = Path(__file__).resolve().parent
project_root = current_dir
sys.path.insert(0, str(project_root))
# 将 backend 目录也加入路径，以便能找到 'app' 模块
sys.path.insert(0, str(project_root / "backend"))

from computer_vision.core.seat_occupancy_detector import SeatOccupancyDetector
# 直接导入时不再带 backend 前缀，因为我们已经把 backend 加入 path 了
from app.services.occupancy_cv_service import _resolve_model_paths

def visualize_video_test(
    video_path: str,
    output_video_path: str = "output_viz.mp4",
    interval_seconds: float = 2, # 每 0.5 秒检测一次，避免处理太慢
    max_duration_seconds: int = 10
):
    """
    运行 CV 模型并生成带有可视化结果的视频文件。
    """
    print(f"Start processing video: {video_path}")
    
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

    # 2. 打开视频
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print("Error: Could not open video file.")
        return

    fps = cap.get(cv2.CAP_PROP_FPS)
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    
    print(f"Video Info: {width}x{height} @ {fps}fps, Total Frames: {total_frames}")

    # 3. 准备输出视频写入器
    fourcc = cv2.VideoWriter_fourcc(*'mp4v') # 或者 'avc1'
    out = cv2.VideoWriter(output_video_path, fourcc, fps, (width, height))
    
    frame_step = max(1, int(round(fps * interval_seconds)))
    
    frame_idx = 0
    processed_count = 0
    
    start_time = time.time()

    while True:
        ret, frame = cap.read()
        if not ret:
            break
            
        # 检查是否超过最大处理时长
        if (frame_idx / fps) > max_duration_seconds:
            print("Reached max duration, stopping.")
            break

        # 只对特定间隔的帧进行推理，其他帧直接写入原图（或者如果你想让视频变流畅，可以每帧都写，但只在关键帧画框）
        # 这里为了演示效果，我们每一帧都写入，但只在 interval 帧进行检测并更新画图结果
        # 但由于 detector.get_occupancy_stats_with_seats 的 visualize=True 会直接保存图片而不是返回画好框的 image 对象
        # 我们需要稍微变通一下：
        # 该方法内部使用了 `visualize=True` 时会保存到 `output_path`。
        # 为了视频流可视化，我们其实需要它返回画好框的图片，或者我们需要修改 detector 代码。
        # 
        # **注意**：查看源代码，visualize=True 只是把结果保存到磁盘上的一个文件，并没有返回给调用者。
        # 这对于视频流处理是不够的。
        # 
        # 既然不能直接获取画好框的图，我们只能让它每帧都推理并保存为临时图片，然后我们再读回来写入视频？这太慢了。
        # 
        # **更好的方案**：我们先不管 detector 内部的 visualize，我们拿到检测结果后，自己用 cv2 在 frame 上画框！
        # 这样效率最高，也最灵活。
        
        # 为了演示，我们对每一帧（或者每N帧）进行推理
        if frame_idx % frame_step == 0:
            print(f"Processing frame {frame_idx}/{total_frames}...")
            
            # 运行推理
            # 注意：这里我们不需要 visualize=True，因为我们要自己画
            # 但是我们需要拿到 bounding boxes。
            # 遗憾的是，get_occupancy_stats_with_seats 只返回统计数据 (Dict)，没有返回 boxes。
            
            # 所以，为了满足你的“能够让我看到可视化的结果”的需求，
            # 我必须强行使用 visualize=True，并将 output_path 指向一个临时文件，
            # 然后读取这个临时文件作为当前帧写入视频。
            
            tmp_viz_path = "temp_viz_frame.jpg"
            detector.get_occupancy_stats_with_seats(
                frame,
                visualize=True,
                output_path=tmp_viz_path,
                # 使用你指定的参数或默认参数
                # confidence_threshold=0.25, # 调低一点以便看到更多结果
                # seat_expansion_factor=1.5
                hogging_item_class_id=list(range(23)),
                person_class_id=23,
                seat_class_id=[56,57]
            )
            
            # 读取可视化后的图片
            viz_frame = cv2.imread(tmp_viz_path)
            if viz_frame is not None:
                # 如果尺寸变了（imgsz处理过），需要resize回原视频尺寸吗？
                # detector 内部可能会 resize，我们需要确认。
                # 如果 viz_frame 尺寸和 frame 不同，resize 它
                if viz_frame.shape[:2] != (height, width):
                    viz_frame = cv2.resize(viz_frame, (width, height))
                
                out.write(viz_frame)
            else:
                # 如果读取失败，写回原帧
                out.write(frame)
                
        else:
            # 跳过的帧，为了保持视频连贯，我们写入原始帧
            # 或者，如果你希望视频里一直显示上一帧的检测结果，你可以缓存上一张 viz_frame
            # 这里简单起见，写入原始帧
            out.write(frame)

        frame_idx += 1
        processed_count += 1

    cap.release()
    out.release()
    print(f"Done! Output saved to: {output_video_path}")
    
    # 清理临时文件
    if Path("temp_viz_frame.jpg").exists():
        Path("temp_viz_frame.jpg").unlink()

if __name__ == "__main__":
    # 自动生成一个测试视频（如果没有提供路径）
    video_file = "545ca475393ee09ace3e1814cc2ff900_raw.mp4"
    
    if not Path(video_file).exists():
        print("Generating dummy test video...")
        # 生成一个 5 秒的视频，使用测试图片
        img_path = Path(project_root) / "computer_vision" / "test" / "data" / "ChiWah" / "10.jpg"
        if img_path.exists():
            img = cv2.imread(str(img_path))
            h, w = img.shape[:2]
            fourcc = cv2.VideoWriter_fourcc(*'XVID')
            out = cv2.VideoWriter(video_file, fourcc, 5.0, (w, h))
            for _ in range(25): # 5秒 * 5fps
                out.write(img)
            out.release()
        else:
            print(f"Error: Test image not found at {img_path}")
            sys.exit(1)
            
    visualize_video_test(video_file)

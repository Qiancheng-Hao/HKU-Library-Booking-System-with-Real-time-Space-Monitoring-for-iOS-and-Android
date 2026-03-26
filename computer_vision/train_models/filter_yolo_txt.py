import os
import shutil
from tqdm import tqdm

# 根据用户提供的 data.yaml 定义原始 ID 到新 ID (0-8) 的映射
ORIG_TO_NEW = {
    49: 0,  # person
    2: 1,   # backpack
    36: 2,  # handbag
    13: 3,  # bottle
    42: 4,  # laptop
    12: 5,  # book
    22: 6,  # chair (seat)
    8: 7,   # bench
    24: 8   # couch (sofa)
}

NEW_CLASSES = ['person', 'backpack', 'handbag', 'bottle', 'laptop', 'book', 'chair', 'bench', 'sofa']

def filter_yolo_data(src_root, dst_root, subset, src_folder_name):
    """
    src_root: 原始数据集根目录 (包含 train, valid, test 等)
    dst_root: 目标数据集根目录
    subset: 目标子集名称 ('train', 'val', 'test')
    src_folder_name: 原始文件夹名称 ('train', 'valid', 'test')
    """
    src_img_dir = os.path.join(src_root, src_folder_name, 'images')
    src_lbl_dir = os.path.join(src_root, src_folder_name, 'labels')
    
    dst_img_dir = os.path.join(dst_root, subset, 'images')
    dst_lbl_dir = os.path.join(dst_root, subset, 'labels')
    
    os.makedirs(dst_img_dir, exist_ok=True)
    os.makedirs(dst_lbl_dir, exist_ok=True)
    
    if not os.path.exists(src_lbl_dir):
        print(f"Warning: Label directory not found: {src_lbl_dir}. Skipping.")
        return

    print(f"Processing {src_folder_name} -> {subset}...")
    
    label_files = [f for f in os.listdir(src_lbl_dir) if f.endswith('.txt')]
    count = 0
    
    for lbl_file in tqdm(label_files):
        src_lbl_path = os.path.join(src_lbl_dir, lbl_file)
        
        keep_lines = []
        with open(src_lbl_path, 'r') as f:
            for line in f:
                parts = line.strip().split()
                if not parts: continue
                orig_id = int(parts[0])
                if orig_id in ORIG_TO_NEW:
                    new_id = ORIG_TO_NEW[orig_id]
                    keep_lines.append(f"{new_id} {' '.join(parts[1:])}\n")
        
        if keep_lines:
            img_name_base = os.path.splitext(lbl_file)[0]
            img_file = None
            for ext in ['.jpg', '.jpeg', '.png', '.JPG', '.JPEG', '.PNG']:
                if os.path.exists(os.path.join(src_img_dir, img_name_base + ext)):
                    img_file = img_name_base + ext
                    break
            
            if img_file:
                with open(os.path.join(dst_lbl_dir, lbl_file), 'w') as f:
                    f.writelines(keep_lines)
                shutil.copy(os.path.join(src_img_dir, img_file), os.path.join(dst_img_dir, img_file))
                count += 1
                
    print(f"Finished {subset}: {count} images saved.")

def create_yaml(dst_root):
    os.makedirs(dst_root, exist_ok=True)
    content = f"""path: {os.path.abspath(dst_root)}
train: train/images
val: val/images
test: test/images

names:
"""
    for i, name in enumerate(NEW_CLASSES):
        content += f"  {i}: {name}\n"
        
    with open(os.path.join(dst_root, 'data.yaml'), 'w') as f:
        f.write(content)
    print(f"Created data.yaml in {dst_root}")

if __name__ == "__main__":
    SOURCE_DIR = "C:/Users/zeyua/Downloads/COCO Dataset"
    OUTPUT_DIR = "C:/Users/zeyua/Downloads/COCO_Filtered_YOLO"
    
    # 映射原始文件夹到目标子集
    subsets = [
        ('train', 'train'),   # 训练集
        ('val', 'valid'),     # 验证集
        ('test', 'test')      # 测试集
    ]
    
    for dst_sub, src_sub in subsets:
        filter_yolo_data(SOURCE_DIR, OUTPUT_DIR, dst_sub, src_sub)
            
    create_yaml(OUTPUT_DIR)

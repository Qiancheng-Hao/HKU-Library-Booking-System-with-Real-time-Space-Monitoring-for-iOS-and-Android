import os
import shutil
from tqdm import tqdm

# 统一后的类别列表 (11个)
FINAL_CLASSES = [
    'person', 'backpack', 'handbag', 'bottle', 'laptop', 
    'book', 'chair', 'bench', 'sofa', 'ipad', 'iphone'
]

# Another Data 原始索引 (Index) 到 统一 ID (0-10) 的映射
# 根据您提供的 names 列表索引：
ANOTHER_TO_UNIFIED = {
    0: 0,   # '0- person' -> person
    3: 1,   # '24- backpack' -> backpack
    5: 2,   # '26- handbag' -> handbag
    8: 3,   # '39- bottle' -> bottle
    16: 4,  # '63- laptop' -> laptop
    25: 4,  # 'macbook' -> laptop (归纳)
    20: 5,  # '73- book' -> book
    10: 6,  # '56- chair' -> chair
    2: 7,   # '13- bench' -> bench
    11: 8,  # '57- couch' -> sofa
    23: 9,  # 'ipad' -> ipad
    24: 10  # 'iphone' -> iphone
}

def merge_datasets(src_root, dst_root, subset_map):
    """
    src_root: another data 的路径
    dst_root: 之前过滤好的 coco dataset 路径
    subset_map: {原始文件夹: 目标文件夹}
    """
    print(f"Merging {src_root} into {dst_root}...")
    
    for src_sub, dst_sub in subset_map.items():
        src_img_dir = os.path.join(src_root, src_sub, 'images')
        src_lbl_dir = os.path.join(src_root, src_sub, 'labels')
        
        dst_img_dir = os.path.join(dst_root, dst_sub, 'images')
        dst_lbl_dir = os.path.join(dst_root, dst_sub, 'labels')
        
        os.makedirs(dst_img_dir, exist_ok=True)
        os.makedirs(dst_lbl_dir, exist_ok=True)
        
        if not os.path.exists(src_lbl_dir):
            print(f"Skip {src_sub}: folder not found.")
            continue

        label_files = [f for f in os.listdir(src_lbl_dir) if f.endswith('.txt')]
        count = 0
        
        for lbl_file in tqdm(label_files, desc=f"Processing {src_sub}"):
            # 1. 处理标签并转换 ID
            keep_lines = []
            with open(os.path.join(src_lbl_dir, lbl_file), 'r') as f:
                for line in f:
                    parts = line.strip().split()
                    if not parts: continue
                    orig_id = int(parts[0])
                    if orig_id in ANOTHER_TO_UNIFIED:
                        new_id = ANOTHER_TO_UNIFIED[orig_id]
                        keep_lines.append(f"{new_id} {' '.join(parts[1:])}\n")
            
            # 2. 如果有目标类别，执行拷贝
            if keep_lines:
                img_name_base = os.path.splitext(lbl_file)[0]
                img_file = None
                for ext in ['.jpg', '.jpeg', '.png', '.JPG', '.PNG']:
                    if os.path.exists(os.path.join(src_img_dir, img_name_base + ext)):
                        img_file = img_name_base + ext
                        break
                
                if img_file:
                    # 使用前缀防止冲突
                    new_name_base = "another_" + img_name_base
                    new_lbl_name = new_name_base + ".txt"
                    new_img_name = new_name_base + os.path.splitext(img_file)[1]
                    
                    # 写入新标签
                    with open(os.path.join(dst_lbl_dir, new_lbl_name), 'w') as f:
                        f.writelines(keep_lines)
                    
                    # 拷贝图片
                    shutil.copy(os.path.join(src_img_dir, img_file), os.path.join(dst_img_dir, new_img_name))
                    count += 1
        
        print(f"Added {count} images to {dst_sub}.")

def update_yaml(dst_root):
    content = f"""path: {os.path.abspath(dst_root)}
train: train/images
val: val/images
test: test/images

names:
"""
    for i, name in enumerate(FINAL_CLASSES):
        content += f"  {i}: {name}\n"
        
    with open(os.path.join(dst_root, 'data.yaml'), 'w') as f:
        f.write(content)
    print(f"Updated data.yaml with 11 classes.")

if __name__ == "__main__":
    ANOTHER_DATA_DIR = "C:/Users/zeyua/Downloads/another data"
    TARGET_DIR = "C:/Users/zeyua/Downloads/COCO_Filtered_YOLO"
    
    # 映射关系: {Another_Data文件夹: 目标文件夹}
    # 注意: 目标文件夹按照您要求的 val/ 结构
    mapping = {
        'train': 'train',
        'valid': 'val',
        'test': 'test'
    }
    
    merge_datasets(ANOTHER_DATA_DIR, TARGET_DIR, mapping)
    update_yaml(TARGET_DIR)

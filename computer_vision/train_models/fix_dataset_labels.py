import os
import yaml
from glob import glob
from tqdm import tqdm

# ==========================================
# CONFIGURATION
# ==========================================
DATASET_DIR = r"C:\Users\zeyua\Downloads\person_and_item_dataset"
DATA_YAML_PATH = os.path.join(DATASET_DIR, "data.yaml")

# Manually define synonyms you want to merge (case-insensitive)
# Format: { 'old_name': 'target_name' }
SYNONYMS = {
    'mobile phone': 'cell phone',
    'water bottle': 'bottle',
    'ipad-pro': 'ipad',
    'ipad-air': 'ipad',
}

def load_yaml(path):
    with open(path, 'r') as f:
        return yaml.safe_load(f)

def save_yaml(data, path):
    with open(path, 'w') as f:
        yaml.dump(data, f, sort_keys=False)

def main():
    if not os.path.exists(DATA_YAML_PATH):
        print(f"Error: Could not find {DATA_YAML_PATH}")
        return

    print(f"Reading {DATA_YAML_PATH}...")
    data = load_yaml(DATA_YAML_PATH)
    names_list = data.get('names')
    
    if isinstance(names_list, dict):
        max_id = max(names_list.keys())
        names_list = [names_list[i] for i in range(max_id + 1)]

    print(f"Found {len(names_list)} original classes.")

    # 1. Identify Duplicates and Synonyms
    remap_ids = {}
    lookup_kept_index = {} # 'bag' -> 0
    final_names = []
    
    print("\nAnalyzing for duplicates and synonyms...")
    
    for old_id, name in enumerate(names_list):
        clean_name = name.lower().strip()
        
        # Check if this name is a synonym of something else
        target_name = SYNONYMS.get(clean_name, clean_name)
        
        if target_name in lookup_kept_index:
            # Duplicate or Synonym found!
            target_new_id = lookup_kept_index[target_name]
            remap_ids[old_id] = target_new_id
            print(f"  [Merge] '{name}' (ID {old_id}) -> '{final_names[target_new_id]}' (ID {target_new_id})")
        else:
            # New unique class
            new_id = len(final_names)
            lookup_kept_index[target_name] = new_id
            # Use the target name (e.g. 'ipad' instead of 'iPad-Air')
            final_names.append(target_name.capitalize() if target_name != 'ipad' else 'iPad')
            
            if old_id != new_id:
                remap_ids[old_id] = new_id
                print(f"  [Shift] '{name}' (ID {old_id}) -> ID {new_id}")

    if not remap_ids:
        print("\nNo changes needed!")
        return

    print(f"\nFinal classes ({len(final_names)}): {final_names}")
    confirm = input("\nDo you want to proceed with modifying .txt files? (y/n): ")
    if confirm.lower() != 'y': return

    # 2. Process Label Files
    # Search in DATASET_DIR and one level up (because of ../ in your yaml)
    search_dirs = [DATASET_DIR, os.path.dirname(DATASET_DIR)]
    label_files = []
    for d in search_dirs:
        label_files.extend(glob(os.path.join(d, "**", "labels", "*.txt"), recursive=True))
    
    label_files = list(set(label_files)) # Remove duplicates
    label_files = [f for f in label_files if 'classes.txt' not in f]
    
    print(f"Found {len(label_files)} label files.")
    
    modified_count = 0
    for file_path in tqdm(label_files):
        with open(file_path, 'r') as f:
            lines = f.readlines()
        
        new_lines = []
        file_changed = False
        for line in lines:
            parts = line.strip().split()
            if not parts: continue
            cls_id = int(parts[0])
            new_id = remap_ids.get(cls_id, cls_id)
            if new_id != cls_id:
                parts[0] = str(new_id)
                new_lines.append(" ".join(parts) + "\n")
                file_changed = True
            else:
                new_lines.append(line)
        
        if file_changed:
            with open(file_path, 'w') as f:
                f.writelines(new_lines)
            modified_count += 1

    # 3. Update data.yaml
    data['names'] = final_names
    data['nc'] = len(final_names)
    save_yaml(data, DATA_YAML_PATH)
    print(f"\nSuccess! Updated {modified_count} files and data.yaml.")

if __name__ == "__main__":
    main()
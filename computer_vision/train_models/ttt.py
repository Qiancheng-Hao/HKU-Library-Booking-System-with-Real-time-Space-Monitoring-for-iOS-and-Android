import os

current_path = os.path.abspath(__file__)
train_models_dir = os.path.dirname(current_path)
computer_vision_dir = os.path.dirname(train_models_dir)
project_dir = os.path.dirname(computer_vision_dir)
# main_dir = os.path.dirname(project_dir)
main_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(current_path))))
# print("main dir:", main_dir)
# dataset_root = os.path.join(main_dir, "person_and_item_dataset")
dataset_root = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(current_path)))), "person_and_item_dataset")
dataset_yaml = os.path.join(dataset_root, "data.yaml")
save_dir = os.path.join(os.path.dirname(os.path.dirname(current_path)), "models", "person_and_item")

# print("dataset root:", dataset_root)
# print("dataset yaml:", dataset_yaml)

print(save_dir)
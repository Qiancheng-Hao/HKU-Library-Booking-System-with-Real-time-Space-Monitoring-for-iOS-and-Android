import os
import matplotlib.pyplot as plt
import numpy as np

# define class names
class_names = [
    'apple pencil', 'backpack', 'bottle', 'calculator', 'cell phone', 
    'chair', 'charging table', 'cup', 'earphones', 'glasses', 
    'ipad', 'laptop', 'lecture notes', 'markers', 'pen', 
    'person', 'student id card', 'wallet', 'watch'
]

# label folder path
label_path = ""

# initialize counts dictionary
counts = {i: 0 for i in range(len(class_names))}

# iterate through label files to count instances
if os.path.exists(label_path):
    for file in os.listdir(label_path):
        if file.endswith('.txt'):
            with open(os.path.join(label_path, file), 'r') as f:
                for line in f:
                    parts = line.split()
                    if parts:
                        cls_id = int(parts[0])
                        if cls_id in counts:
                            counts[cls_id] += 1
else:
    print(f"Path {label_path} does not exist. Please check!")

# Plot: Detailed distribution of 19 classes
plt.figure(figsize=(12, 6))
colors = ['#707070' if x == 'chair' else '#191919' if x == 'person' else '#c1c1bf' for x in class_names]
plt.bar(class_names, [counts[i] for i in range(len(class_names))], color=colors)
plt.xticks(rotation=45, ha='right')
plt.title('Detailed Class Distribution (19 Classes)')
plt.ylabel('Number of Instances')
plt.tight_layout()
plt.savefig('detailed_distribution.png')
plt.show()

# Plot: Logical group distribution 
groups = {'Seats (Chair)': counts[5], 'Persons': counts[15], 'Items (17 types)': sum(v for k, v in counts.items() if k not in [5, 15])}

plt.figure(figsize=(8, 5))
plt.bar(groups.keys(), groups.values(), color=['#707070', '#191919', '#c1c1bf'])
plt.title('Data Imbalance: Why We Need Dual-Model Strategy')
plt.ylabel('Total Instances')

# Annotate bars with counts
for i, v in enumerate(groups.values()):
    plt.text(i, v + (max(groups.values())*0.01), str(v), ha='center', fontweight='bold')

plt.tight_layout()
plt.savefig('grouped_distribution.png')
plt.show()
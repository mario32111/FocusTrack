import os
import random
from PIL import Image
import matplotlib.pyplot as plt
import matplotlib.patches as patches
import cv2
import numpy as np

base_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'PTA-2', 'train')
img_path = os.path.join(base_dir, 'images')
label_path = os.path.join(base_dir, 'labels')

classname = ['Distracted', 'Drowsy', 'Eating', 'No seatbelt', 'Seatbelt', 'Smoking']

num_data = 15

all_imgs = sorted(os.listdir(img_path))
all_labels = sorted(os.listdir(label_path))

selected_indices = random.sample(range(len(all_imgs)), num_data)
imgs = [all_imgs[i] for i in selected_indices]
labels = [all_labels[i] for i in selected_indices]

fig, axes = plt.subplots(3, 5, figsize=(21, 15))

for idx, ax in enumerate(axes.flat):
    if idx < len(imgs):
        try:
            img_path_full = os.path.join(img_path, imgs[idx])
            img = np.array(Image.open(img_path_full))
            img_h, img_w, _ = img.shape

            label_path_full = os.path.join(label_path, labels[idx])
            with open(label_path_full, 'r') as file:
                ann = file.read().strip().split()

                if len(ann) < 5:
                    print(f"Skipping {labels[idx]}: Insufficient values in annotation")
                    continue

                label = int(ann[0])
                x, y, w, h = map(float, ann[1:5])
                x_center, y_center = x * img_w, y * img_h
                box_w, box_h = w * img_w, h * img_h

                x1 = x_center - box_w // 2
                y1 = y_center - box_h // 2
                x2 = x_center + box_w // 2
                y2 = y_center + box_h // 2

                bbox = patches.Rectangle((x1, y1), box_w, box_h, linewidth=2, edgecolor='red', facecolor='none')
                ax.add_patch(bbox)
                ax.set_title(f'{classname[label]}', fontsize=20)
            ax.imshow(img)
            ax.axis('off')
        except Exception as e:
            print(f"Error with {imgs[idx]}: {e}")
            ax.axis('off')
plt.tight_layout()
plt.show()

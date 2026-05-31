import cv2
import torch
import numpy as np
from ultralytics import YOLO
from tqdm import tqdm
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_YAML = os.path.join(BASE_DIR, 'PTA-2', 'data.yaml')

model = YOLO('yolo11n.pt', verbose=False)

model.train(data=DATA_YAML,
            epochs=50,
            patience=5,
            save=True,
            device=torch.device('cuda' if torch.cuda.is_available() else 'cpu'),
            project='MOT')
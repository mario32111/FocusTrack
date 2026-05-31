import cv2
import torch
import numpy as np
from ultralytics import YOLO
from tqdm import tqdm
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_YAML = os.path.join(BASE_DIR, 'PTA-2', 'data.yaml')
WEIGHTS = os.path.join(BASE_DIR, 'runs', 'detect', 'MOT', 'train', 'weights', 'last.pt')

model = YOLO(WEIGHTS, verbose=True)

results = model.val(data=DATA_YAML)
import os
import json
import io
import cv2
import numpy as np
from fastapi import FastAPI, UploadFile, File, HTTPException
from ultralytics import YOLO
from PIL import Image

app = FastAPI(title="API Detection (YOLO)")

# ─── Mapeo de clases del modelo a etiquetas del backend ───
LABEL_MAP = {
    "Distracted": "distraccion",
    "Drowsy":     "somnolencia",
    "Eating":     "comiendo",
    "No seatbelt":"sin_cinturon",
    "Seatbelt":   "cinturon",
    "Smoking":    "fumando",
}

# Clases que se consideran "malos hábitos"
BAD_HABITS = {"distraccion", "somnolencia", "comiendo", "sin_cinturon", "fumando"}

# Cargar el modelo YOLO en memoria al arrancar la API
MODEL_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "best2.pt")
print(f"[INFO] Cargando modelo YOLO desde {MODEL_PATH}...")
try:
    model = YOLO(MODEL_PATH)
    print("[INFO] Modelo cargado correctamente.")
except Exception as e:
    print(f"[ERROR] No se pudo cargar el modelo: {e}")
    model = None


@app.get("/")
def read_root():
    return {"message": "API Detection YOLO funcionando correctamente"}


@app.post("/predict")
async def predict_image(evidencia: UploadFile = File(...)):
    """
    Recibe una imagen, corre el modelo YOLO y devuelve las detecciones
    de malos hábitos en formato JSON.
    """
    if model is None:
        raise HTTPException(status_code=500, detail="El modelo YOLO no está cargado")

    try:
        # Leer la imagen desde el multipart
        image_bytes = await evidencia.read()
        
        # Convertir bytes a formato apto para OpenCV/YOLO
        image = Image.open(io.BytesIO(image_bytes))
        img_np = np.array(image)
        
        # Si la imagen es RGBA (tiene canal alfa), convertirla a RGB
        if img_np.shape[-1] == 4:
            img_np = cv2.cvtColor(img_np, cv2.COLOR_RGBA2RGB)
        elif len(img_np.shape) == 2:
            # Grayscale a RGB
            img_np = cv2.cvtColor(img_np, cv2.COLOR_GRAY2RGB)

        # Inferencia
        results = model.predict(source=img_np, conf=0.15, imgsz=640, verbose=False)
        
        detections = []
        boxes = results[0].boxes

        if boxes is not None and len(boxes) > 0:
            for box in boxes:
                cls_id = int(box.cls[0])
                confidence = float(box.conf[0])
                class_name = results[0].names[cls_id]
                etiqueta = LABEL_MAP.get(class_name, class_name.lower())

                if etiqueta in BAD_HABITS:
                    detections.append({
                        "etiqueta": etiqueta,
                        "confianza": round(confidence, 4)
                    })

        return {"detecciones": detections}

    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error procesando la imagen: {str(e)}")

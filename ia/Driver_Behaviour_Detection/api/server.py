"""
FocusTrack AI - FastAPI Server Intermedio
==========================================
Recibe datos de sensores (IMU, BPM) e imágenes del conductor
desde un cliente (ej. app móvil), evalúa umbrales y reenvía
los datos relevantes al backend principal.

Responsabilidades:
  1. Recibir eventos vía form-data (soporta fotos + campos JSON)
  2. Evaluar umbrales:
     - IA: corre YOLO sobre la imagen, filtra por confianza por etiqueta
     - IMU/Giroscopio: modelo simulado que predice "maniobra brusca"
     - BPM: evalúa rango de pulsaciones
  3. Reenviar solo los datos que superen los umbrales al backend final

Uso:
    python server.py --port 8000 --backend-url http://localhost:3000

Endpoints:
    POST /viajes/{viaje_id}/eventos  →  Recibe y evalúa cualquier tipo de evento
    GET  /health                     →  Health check
    GET  /config                     →  Ver configuración actual de umbrales
    PUT  /config/umbrales            →  Actualizar umbrales dinámicamente
"""

import cv2
import numpy as np
import json
import random
import math
import os
import argparse
import uvicorn
import requests as http_requests
from datetime import datetime, timezone
from typing import Optional
from contextlib import asynccontextmanager

from ultralytics import YOLO

from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.responses import JSONResponse


# ═══════════════════════════════════════════════════════════
# CONFIGURACIÓN Y CONSTANTES
# ═══════════════════════════════════════════════════════════

# Mapeo de clases del modelo → etiquetas del backend (mismo que client.py)
LABEL_MAP = {
    "Distracted": "distraccion",
    "Drowsy":     "somnolencia",
    "Eating":     "comiendo",
    "No seatbelt":"sin_cinturon",
    "Seatbelt":   "cinturon",
    "Smoking":    "fumando",
}

# Clases que se consideran "malos hábitos" (se envían al backend)
BAD_HABITS = {"distraccion", "somnolencia", "comiendo", "sin_cinturon", "fumando"}

# Directorio raíz del proyecto (un nivel arriba de api/)
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class ServerConfig:
    """Configuración global del servidor, modificable en runtime."""

    def __init__(self):
        # URL base del backend al que se reenvían los eventos
        self.backend_url: str = "http://localhost:3000"

        # ── Modelo YOLO ──
        self.model_path: str = "best2.pt"
        self.yolo_conf: float = 0.15   # Umbral de confianza para YOLO (inferencia)
        self.yolo_imgsz: int = 640

        # ── Umbrales de IA (filtrado post-inferencia por etiqueta) ──
        # Si CUALQUIER etiqueta de mal hábito supera este umbral, se envía
        self.umbral_confianza_ia: float = 0.10

        # ── Umbrales de IMU / Giroscopio (maniobra brusca) ──
        self.umbral_prediccion_maniobra: float = 0.60
        self.umbral_gyro_abs: float = 15.0
        self.umbral_acc_lateral: float = 2.5

        # ── Umbrales de BPM ──
        self.umbral_bpm_alto: int = 100
        self.umbral_bpm_bajo: int = 55

        # Contadores de eventos
        self.eventos_recibidos: int = 0
        self.eventos_reenviados: int = 0
        self.eventos_descartados: int = 0


config = ServerConfig()

# Modelo YOLO global (se carga una sola vez al iniciar)
yolo_model = None


# ═══════════════════════════════════════════════════════════
# LIFECYCLE (Cargar modelo al iniciar)
# ═══════════════════════════════════════════════════════════

@asynccontextmanager
async def lifespan(app):
    """Carga el modelo YOLO al iniciar el servidor."""
    global yolo_model
    model_path = os.path.join(PROJECT_ROOT, config.model_path)
    print(f"\n[INFO] Cargando modelo YOLO desde: {model_path}")
    yolo_model = YOLO(model_path)
    print("[INFO] Modelo YOLO cargado correctamente.\n")
    yield
    print("[INFO] Servidor detenido.")


# ═══════════════════════════════════════════════════════════
# FASTAPI APP
# ═══════════════════════════════════════════════════════════

app = FastAPI(
    title="FocusTrack AI - Server Intermedio",
    description=(
        "Servidor intermedio que recibe imágenes y datos de sensores, "
        "ejecuta detección con YOLO, evalúa umbrales, y reenvía al "
        "backend principal solo los eventos que superen los criterios."
    ),
    version="2.0.0",
    lifespan=lifespan,
)


# ═══════════════════════════════════════════════════════════
# FUNCIONES DE IA (YOLO) — Tomadas de client.py
# ═══════════════════════════════════════════════════════════

def build_detections(results):
    """
    Extrae las detecciones del resultado de YOLO y las convierte
    al formato esperado por el endpoint.
    Solo incluye detecciones de malos hábitos.
    (Misma función que en client.py)
    """
    detections = []
    boxes = results[0].boxes

    if boxes is None or len(boxes) == 0:
        return detections

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

    return detections


def run_yolo_on_image(image_bytes: bytes) -> tuple:
    """
    Ejecuta YOLO sobre una imagen recibida en bytes.

    Retorna:
        (detections, frame_bytes_jpeg)
        - detections: lista de dict con etiqueta y confianza
        - frame_bytes_jpeg: imagen original en bytes JPEG (para reenviar)
    """
    # Decodificar bytes → numpy array (imagen OpenCV)
    nparr = np.frombuffer(image_bytes, np.uint8)
    frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    if frame is None:
        return [], None

    # Convertir BGR → RGB para YOLO
    img_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

    # Inferencia
    results = yolo_model.predict(
        source=img_rgb,
        conf=config.yolo_conf,
        imgsz=config.yolo_imgsz,
        verbose=False,
    )

    # Extraer detecciones de malos hábitos
    detections = build_detections(results)

    # Re-codificar la imagen original a JPEG para reenviar
    success, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
    frame_bytes = buffer.tobytes() if success else None

    return detections, frame_bytes


# ═══════════════════════════════════════════════════════════
# UTILIDADES
# ═══════════════════════════════════════════════════════════

def get_timestamp() -> str:
    """Genera un timestamp ISO 8601 en UTC."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def simular_prediccion_maniobra(gyro_x: float, acc_x: float, acc_y: float, acc_z: float) -> dict:
    """
    Simula un modelo de clasificación que predice si los datos del
    giroscopio/acelerómetro corresponden a una maniobra brusca.

    En producción esto sería un modelo entrenado (ej. Random Forest, LSTM).
    """
    gyro_factor = min(abs(gyro_x) / 30.0, 1.0)
    acc_lat_factor = min(abs(acc_x) / 4.0, 1.0)
    acc_z_deviation = abs(acc_z - 9.81)
    acc_z_factor = min(acc_z_deviation / 2.0, 1.0)
    acc_vert_factor = min(abs(acc_y) / 3.0, 1.0)

    probabilidad_base = (
        gyro_factor * 0.40 +
        acc_lat_factor * 0.30 +
        acc_z_factor * 0.15 +
        acc_vert_factor * 0.15
    )

    ruido = random.gauss(0, 0.05)
    probabilidad = max(0.0, min(1.0, probabilidad_base + ruido))

    return {
        "es_maniobra_brusca": probabilidad >= config.umbral_prediccion_maniobra,
        "probabilidad": round(probabilidad, 4),
        "factores": {
            "gyro_factor": round(gyro_factor, 4),
            "acc_lateral_factor": round(acc_lat_factor, 4),
            "acc_z_factor": round(acc_z_factor, 4),
            "acc_vertical_factor": round(acc_vert_factor, 4),
        }
    }


def evaluar_umbral_bpm(pulsaciones: int) -> dict:
    """Evalúa si las pulsaciones cardíacas están fuera del rango normal."""
    if pulsaciones >= config.umbral_bpm_alto:
        return {"fuera_de_rango": True, "tipo": "alto", "pulsaciones": pulsaciones}
    elif pulsaciones <= config.umbral_bpm_bajo:
        return {"fuera_de_rango": True, "tipo": "bajo", "pulsaciones": pulsaciones}
    else:
        return {"fuera_de_rango": False, "tipo": "normal", "pulsaciones": pulsaciones}


def filtrar_detecciones_por_umbral(detecciones: list) -> list:
    """
    Filtra las detecciones de IA que superen el umbral de confianza.
    Si CUALQUIER etiqueta de mal hábito tiene confianza >= umbral, se incluye.
    """
    filtradas = []
    for det in detecciones:
        etiqueta = det.get("etiqueta", "")
        confianza = det.get("confianza", 0.0)

        if etiqueta in BAD_HABITS and confianza >= config.umbral_confianza_ia:
            filtradas.append(det)

    return filtradas


# ═══════════════════════════════════════════════════════════
# FUNCIONES DE REENVÍO AL BACKEND
# ═══════════════════════════════════════════════════════════

def reenviar_evento_ia(viaje_id: str, evidencia_bytes: bytes, detecciones: list, timestamp: str):
    """
    Reenvía un evento de IA (con imagen) al backend final.
    Mantiene la misma estructura que usa client.py.
    """
    endpoint_url = f"{config.backend_url}/viajes/{viaje_id}/eventos"

    files = {
        "evidencia": ("frame.jpg", evidencia_bytes, "image/jpeg"),
    }
    data = {
        "tipo": "IA",
        "detecciones": json.dumps(detecciones),
        "timestamp": timestamp,
    }

    try:
        response = http_requests.post(endpoint_url, files=files, data=data, timeout=10)
        return response.status_code, response.text
    except http_requests.exceptions.ConnectionError:
        return None, "Error: No se pudo conectar al backend"
    except http_requests.exceptions.Timeout:
        return None, "Error: Timeout"
    except Exception as e:
        return None, f"Error: {e}"


def reenviar_evento_json(viaje_id: str, tipo: str, datos: dict, timestamp: str):
    """
    Reenvía un evento JSON (IMU o BPM) al backend final.
    Mantiene la misma estructura que usa client.py.
    """
    endpoint_url = f"{config.backend_url}/viajes/{viaje_id}/eventos"

    payload = {
        "tipo": tipo,
        "datos": json.dumps(datos) if isinstance(datos, dict) else datos,
        "timestamp": timestamp,
    }

    try:
        response = http_requests.post(endpoint_url, data=payload, timeout=10)
        return response.status_code, response.text
    except http_requests.exceptions.ConnectionError:
        return None, "Error: No se pudo conectar al backend"
    except http_requests.exceptions.Timeout:
        return None, "Error: Timeout"
    except Exception as e:
        return None, f"Error: {e}"


# ═══════════════════════════════════════════════════════════
# ENDPOINTS
# ═══════════════════════════════════════════════════════════

@app.get("/health")
async def health_check():
    """Health check del servidor."""
    return {
        "status": "ok",
        "service": "FocusTrack AI Server Intermedio",
        "modelo_cargado": yolo_model is not None,
        "timestamp": get_timestamp(),
        "estadisticas": {
            "eventos_recibidos": config.eventos_recibidos,
            "eventos_reenviados": config.eventos_reenviados,
            "eventos_descartados": config.eventos_descartados,
        },
    }


@app.get("/config")
async def get_config():
    """Retorna la configuración actual de umbrales."""
    return {
        "backend_url": config.backend_url,
        "modelo": {
            "path": config.model_path,
            "yolo_conf": config.yolo_conf,
            "yolo_imgsz": config.yolo_imgsz,
        },
        "umbrales": {
            "ia": {
                "confianza_minima": config.umbral_confianza_ia,
            },
            "imu": {
                "prediccion_maniobra": config.umbral_prediccion_maniobra,
                "gyro_abs": config.umbral_gyro_abs,
                "acc_lateral": config.umbral_acc_lateral,
            },
            "bpm": {
                "alto": config.umbral_bpm_alto,
                "bajo": config.umbral_bpm_bajo,
            },
        },
    }


@app.put("/config/umbrales")
async def update_umbrales(
    umbral_confianza_ia: Optional[float] = Form(None),
    umbral_prediccion_maniobra: Optional[float] = Form(None),
    umbral_gyro_abs: Optional[float] = Form(None),
    umbral_acc_lateral: Optional[float] = Form(None),
    umbral_bpm_alto: Optional[int] = Form(None),
    umbral_bpm_bajo: Optional[int] = Form(None),
    backend_url: Optional[str] = Form(None),
):
    """Actualiza los umbrales dinámicamente sin reiniciar el server."""
    cambios = {}

    if umbral_confianza_ia is not None:
        config.umbral_confianza_ia = umbral_confianza_ia
        cambios["umbral_confianza_ia"] = umbral_confianza_ia

    if umbral_prediccion_maniobra is not None:
        config.umbral_prediccion_maniobra = umbral_prediccion_maniobra
        cambios["umbral_prediccion_maniobra"] = umbral_prediccion_maniobra

    if umbral_gyro_abs is not None:
        config.umbral_gyro_abs = umbral_gyro_abs
        cambios["umbral_gyro_abs"] = umbral_gyro_abs

    if umbral_acc_lateral is not None:
        config.umbral_acc_lateral = umbral_acc_lateral
        cambios["umbral_acc_lateral"] = umbral_acc_lateral

    if umbral_bpm_alto is not None:
        config.umbral_bpm_alto = umbral_bpm_alto
        cambios["umbral_bpm_alto"] = umbral_bpm_alto

    if umbral_bpm_bajo is not None:
        config.umbral_bpm_bajo = umbral_bpm_bajo
        cambios["umbral_bpm_bajo"] = umbral_bpm_bajo

    if backend_url is not None:
        config.backend_url = backend_url
        cambios["backend_url"] = backend_url

    if not cambios:
        return {"message": "No se proporcionaron cambios", "cambios": {}}

    return {"message": "Umbrales actualizados", "cambios": cambios}


# ─────────────────────────────────────────────────────────
# EVENTO TIPO IA (Detección de imágenes con YOLO)
# ─────────────────────────────────────────────────────────

@app.post("/viajes/{viaje_id}/eventos/ia")
async def recibir_evento_ia(
    viaje_id: str,
    evidencia: UploadFile = File(...),
    timestamp: Optional[str] = Form(None),
):
    """
    Recibe una imagen del conductor, ejecuta YOLO para detectar
    malos hábitos, evalúa el umbral de confianza por etiqueta,
    y reenvía al backend solo si alguna detección lo supera.

    Solo requiere el campo 'evidencia' (imagen).
    El servidor hace la inferencia internamente.
    """
    config.eventos_recibidos += 1
    ts = timestamp or get_timestamp()

    print(f"\n{'─'*50}")
    print(f"[IA RECIBIDO #{config.eventos_recibidos}] Viaje: {viaje_id}")

    # Leer bytes de la imagen
    image_bytes = await evidencia.read()

    if not image_bytes:
        raise HTTPException(status_code=400, detail="La imagen está vacía")

    print(f"  Imagen recibida: {len(image_bytes)} bytes")

    # Ejecutar YOLO sobre la imagen
    detecciones, frame_bytes = run_yolo_on_image(image_bytes)

    print(f"  Detecciones YOLO (malos hábitos): {len(detecciones)}")

    if not detecciones:
        config.eventos_descartados += 1
        print(f"  ⏩ DESCARTADO: No se detectaron malos hábitos")
        return JSONResponse(
            status_code=200,
            content={
                "status": "descartado",
                "razon": "No se detectaron malos hábitos en la imagen",
                "detecciones": [],
            }
        )

    # Filtrar por umbral de confianza por etiqueta
    detecciones_filtradas = filtrar_detecciones_por_umbral(detecciones)

    for det in detecciones:
        pasa = "✓" if det in detecciones_filtradas else "✗"
        print(f"    {pasa} {det['etiqueta']}: {det['confianza']:.4f} "
              f"(umbral: {config.umbral_confianza_ia})")

    if not detecciones_filtradas:
        config.eventos_descartados += 1
        print(f"  ⏩ DESCARTADO: Ninguna detección supera el umbral ({config.umbral_confianza_ia})")
        return JSONResponse(
            status_code=200,
            content={
                "status": "descartado",
                "razon": "Ninguna detección supera el umbral de confianza",
                "umbral": config.umbral_confianza_ia,
                "detecciones_todas": detecciones,
                "detecciones_filtradas": [],
            }
        )

    # Reenviar al backend con la imagen + detecciones filtradas
    if frame_bytes:
        status, response_text = reenviar_evento_ia(
            viaje_id, frame_bytes, detecciones_filtradas, ts
        )
    else:
        # Fallback: usar la imagen original tal cual
        status, response_text = reenviar_evento_ia(
            viaje_id, image_bytes, detecciones_filtradas, ts
        )

    config.eventos_reenviados += 1
    det_summary = ", ".join(
        f"{d['etiqueta']}({d['confianza']:.2f})" for d in detecciones_filtradas
    )
    print(f"  ✅ REENVIADO: {det_summary} → HTTP {status}")

    return JSONResponse(
        status_code=200,
        content={
            "status": "reenviado",
            "detecciones_filtradas": detecciones_filtradas,
            "detecciones_todas": detecciones,
            "backend_status": status,
            "backend_response": response_text,
        }
    )


# ─────────────────────────────────────────────────────────
# EVENTO TIPO IMU (Giroscopio + Acelerómetro)
# ─────────────────────────────────────────────────────────

@app.post("/viajes/{viaje_id}/eventos/imu")
async def recibir_evento_imu(
    viaje_id: str,
    datos: str = Form(...),
    timestamp: Optional[str] = Form(None),
):
    """
    Recibe datos de IMU (giroscopio + acelerómetro), ejecuta el modelo
    simulado de predicción de maniobra brusca, y reenvía al backend
    solo si la predicción supera el umbral.

    El campo 'datos' debe ser un JSON string con:
        acc_x, acc_y, acc_z, gyro_x
    """
    config.eventos_recibidos += 1
    ts = timestamp or get_timestamp()

    print(f"\n{'─'*50}")
    print(f"[IMU RECIBIDO #{config.eventos_recibidos}] Viaje: {viaje_id}")

    try:
        datos_imu = json.loads(datos)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="El campo 'datos' no es un JSON válido")

    acc_x = datos_imu.get("acc_x", 0.0)
    acc_y = datos_imu.get("acc_y", 0.0)
    acc_z = datos_imu.get("acc_z", 9.81)
    gyro_x = datos_imu.get("gyro_x", 0.0)

    # Ejecutar modelo simulado de predicción de maniobra brusca
    prediccion = simular_prediccion_maniobra(gyro_x, acc_x, acc_y, acc_z)

    print(f"  Datos: acc=({acc_x:.2f}, {acc_y:.2f}, {acc_z:.2f}) gyro={gyro_x:.2f}°/s")
    print(f"  Predicción: prob={prediccion['probabilidad']:.4f} "
          f"(umbral={config.umbral_prediccion_maniobra})")

    if not prediccion["es_maniobra_brusca"]:
        config.eventos_descartados += 1
        print(f"  ⏩ DESCARTADO: No es maniobra brusca")
        return JSONResponse(
            status_code=200,
            content={
                "status": "descartado",
                "razon": "La predicción no supera el umbral de maniobra brusca",
                "prediccion": prediccion,
                "datos_imu": datos_imu,
            }
        )

    # Enriquecer datos con la predicción antes de reenviar
    datos_enriquecidos = {
        **datos_imu,
        "prediccion_maniobra": prediccion,
    }

    status, response_text = reenviar_evento_json(viaje_id, "IMU", datos_enriquecidos, ts)

    config.eventos_reenviados += 1
    print(f"  ⚠️  REENVIADO (MANIOBRA BRUSCA): prob={prediccion['probabilidad']:.4f} → HTTP {status}")

    return JSONResponse(
        status_code=200,
        content={
            "status": "reenviado",
            "prediccion": prediccion,
            "datos_enviados": datos_enriquecidos,
            "backend_status": status,
            "backend_response": response_text,
        }
    )


# ─────────────────────────────────────────────────────────
# EVENTO TIPO BPM (Pulsaciones)
# ─────────────────────────────────────────────────────────

@app.post("/viajes/{viaje_id}/eventos/bpm")
async def recibir_evento_bpm(
    viaje_id: str,
    datos: str = Form(...),
    timestamp: Optional[str] = Form(None),
):
    """
    Recibe datos de BPM (pulsaciones cardíacas), evalúa si están
    fuera del rango normal, y reenvía al backend solo si lo están.

    El campo 'datos' debe ser un JSON string con:
        pulsaciones (int)
    """
    config.eventos_recibidos += 1
    ts = timestamp or get_timestamp()

    print(f"\n{'─'*50}")
    print(f"[BPM RECIBIDO #{config.eventos_recibidos}] Viaje: {viaje_id}")

    try:
        datos_bpm = json.loads(datos)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="El campo 'datos' no es un JSON válido")

    pulsaciones = datos_bpm.get("pulsaciones", 72)
    evaluacion = evaluar_umbral_bpm(pulsaciones)

    print(f"  BPM: {pulsaciones} → Estado: {evaluacion['tipo']}")

    if not evaluacion["fuera_de_rango"]:
        config.eventos_descartados += 1
        print(f"  ⏩ DESCARTADO: BPM en rango normal ({pulsaciones})")
        return JSONResponse(
            status_code=200,
            content={
                "status": "descartado",
                "razon": f"BPM en rango normal ({config.umbral_bpm_bajo}-{config.umbral_bpm_alto})",
                "evaluacion": evaluacion,
            }
        )

    status, response_text = reenviar_evento_json(viaje_id, "BPM", datos_bpm, ts)

    config.eventos_reenviados += 1
    indicador = "🔴" if evaluacion["tipo"] == "alto" else "💤"
    print(f"  {indicador} REENVIADO (BPM {evaluacion['tipo'].upper()}): {pulsaciones} → HTTP {status}")

    return JSONResponse(
        status_code=200,
        content={
            "status": "reenviado",
            "evaluacion": evaluacion,
            "backend_status": status,
            "backend_response": response_text,
        }
    )


# ═══════════════════════════════════════════════════════════
# EJECUCIÓN DIRECTA
# ═══════════════════════════════════════════════════════════

def parse_args():
    parser = argparse.ArgumentParser(
        description="FocusTrack AI - Server Intermedio (FastAPI)"
    )
    parser.add_argument(
        "--host", default="0.0.0.0",
        help="Host del servidor (default: 0.0.0.0)"
    )
    parser.add_argument(
        "--port", type=int, default=8000,
        help="Puerto del servidor (default: 8000)"
    )
    parser.add_argument(
        "--backend-url", default="http://localhost:3000",
        help="URL base del backend final (default: http://localhost:3000)"
    )
    # ── Modelo ──
    parser.add_argument(
        "--model", default="best2.pt",
        help="Ruta al modelo YOLO (default: best2.pt)"
    )
    parser.add_argument(
        "--conf", type=float, default=0.15,
        help="Umbral de confianza para YOLO inferencia (default: 0.15)"
    )
    # ── Umbrales ──
    parser.add_argument(
        "--umbral-confianza", type=float, default=0.10,
        help="Umbral de confianza mínima por etiqueta para reenviar (default: 0.10)"
    )
    parser.add_argument(
        "--umbral-maniobra", type=float, default=0.60,
        help="Umbral de probabilidad para maniobra brusca (default: 0.60)"
    )
    parser.add_argument(
        "--umbral-bpm-alto", type=int, default=100,
        help="BPM alto para considerar estrés (default: 100)"
    )
    parser.add_argument(
        "--umbral-bpm-bajo", type=int, default=55,
        help="BPM bajo para considerar somnolencia (default: 55)"
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()

    # Aplicar configuración desde argumentos CLI
    config.backend_url = args.backend_url
    config.model_path = args.model
    config.yolo_conf = args.conf
    config.umbral_confianza_ia = args.umbral_confianza
    config.umbral_prediccion_maniobra = args.umbral_maniobra
    config.umbral_bpm_alto = args.umbral_bpm_alto
    config.umbral_bpm_bajo = args.umbral_bpm_bajo

    print("=" * 60)
    print("  FocusTrack AI - Server Intermedio (FastAPI) v2.0")
    print("=" * 60)
    print(f"  Host:              {args.host}:{args.port}")
    print(f"  Backend URL:       {config.backend_url}")
    print(f"  Modelo YOLO:       {config.model_path}")
    print(f"  YOLO conf:         {config.yolo_conf}")
    print(f"  ── Umbrales de reenvío ──")
    print(f"  IA confianza:      ≥ {config.umbral_confianza_ia}")
    print(f"  Maniobra brusca:   ≥ {config.umbral_prediccion_maniobra}")
    print(f"  BPM alto:          ≥ {config.umbral_bpm_alto}")
    print(f"  BPM bajo:          ≤ {config.umbral_bpm_bajo}")
    print("=" * 60)

    uvicorn.run(
        "server:app",
        host=args.host,
        port=args.port,
        reload=False,
        log_level="info",
    )

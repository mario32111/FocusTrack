"""
FocusTrack AI - Server de Detección en Tiempo Real + Sensores Simulados
========================================================================
Ejecuta la detección de comportamiento del conductor con YOLO
y simula datos de sensores (IMU + BPM), enviando todo al backend.

Hilos de ejecución:
  1. CÁMARA + IA   → Detecta hábitos, envía fotograma + detecciones (tipo: IA)
  2. IMU (simulado) → Acelerómetro + giroscopio con frenadas bruscas (tipo: IMU)
  3. BPM (simulado) → Pulsaciones cardíacas con variación realista (tipo: BPM)

Uso:
    python server.py --viaje <ID_VIAJE> [--url http://localhost:3000] [opciones]

Ejemplo:
    python server.py --viaje abc123 --url http://localhost:3000 --intervalo-ia 3
"""

import cv2
import argparse
import requests
import json
import time
import sys
import os
import math
import random
import threading
from datetime import datetime, timezone
from ultralytics import YOLO


# ─── Mapeo de clases del modelo a etiquetas del backend ───
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

# Flag global para detener todos los hilos
stop_event = threading.Event()


# ═══════════════════════════════════════════════════════════
# ARGUMENTOS CLI
# ═══════════════════════════════════════════════════════════

def parse_args():
    parser = argparse.ArgumentParser(
        description="FocusTrack AI - Detección + Sensores Simulados"
    )
    parser.add_argument(
        "--viaje", required=True,
        help="ID del viaje activo (se usa en la URL del endpoint)"
    )
    parser.add_argument(
        "--url", default="http://localhost:3000",
        help="URL base del backend (default: http://localhost:3000)"
    )
    # ── Intervalos por tipo de evento ──
    parser.add_argument(
        "--intervalo-ia", type=float, default=3.0,
        help="Segundos entre envíos de IA/cámara (default: 3)"
    )
    parser.add_argument(
        "--intervalo-imu", type=float, default=1.0,
        help="Segundos entre envíos de IMU (default: 1)"
    )
    parser.add_argument(
        "--intervalo-bpm", type=float, default=5.0,
        help="Segundos entre envíos de BPM (default: 5)"
    )
    # ── Modelo y cámara ──
    parser.add_argument(
        "--conf", type=float, default=0.15,
        help="Umbral de confianza para YOLO (default: 0.15)"
    )
    parser.add_argument(
        "--camera", type=int, default=0,
        help="Índice de la cámara (default: 0)"
    )
    parser.add_argument(
        "--model", default="best2.pt",
        help="Ruta al modelo YOLO (default: best2.pt)"
    )
    parser.add_argument(
        "--no-display", action="store_true",
        help="Ejecutar sin mostrar la ventana de video (modo headless)"
    )
    # ── Control de sensores ──
    parser.add_argument(
        "--no-imu", action="store_true",
        help="Desactivar simulación de IMU"
    )
    parser.add_argument(
        "--no-bpm", action="store_true",
        help="Desactivar simulación de BPM"
    )
    return parser.parse_args()


# ═══════════════════════════════════════════════════════════
# UTILIDADES DE RED
# ═══════════════════════════════════════════════════════════

def get_timestamp():
    """Genera un timestamp ISO 8601 en UTC."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def send_event_json(endpoint_url, tipo, datos, timestamp=None):
    """
    Envía un evento JSON (IMU o BPM) al backend.
    No usa multipart/form-data, solo JSON en el body.
    """
    payload = {
        "tipo": tipo,
        "datos": json.dumps(datos) if isinstance(datos, dict) else datos,
        "timestamp": timestamp or get_timestamp(),
    }

    try:
        response = requests.post(endpoint_url, data=payload, timeout=10)
        return response.status_code, response.text
    except requests.exceptions.ConnectionError:
        return None, "Error: No se pudo conectar al backend"
    except requests.exceptions.Timeout:
        return None, "Error: Timeout"
    except Exception as e:
        return None, f"Error: {e}"


def send_event_ia(endpoint_url, frame_bytes, detections, timestamp=None):
    """
    Envía un evento de IA (con imagen) al backend via multipart/form-data.
    """
    files = {
        "evidencia": ("frame.jpg", frame_bytes, "image/jpeg"),
    }
    data = {
        "tipo": "IA",
        "detecciones": json.dumps(detections),
        "timestamp": timestamp or get_timestamp(),
    }

    try:
        response = requests.post(endpoint_url, files=files, data=data, timeout=10)
        return response.status_code, response.text
    except requests.exceptions.ConnectionError:
        return None, "Error: No se pudo conectar al backend"
    except requests.exceptions.Timeout:
        return None, "Error: Timeout"
    except Exception as e:
        return None, f"Error: {e}"


# ═══════════════════════════════════════════════════════════
# SIMULADOR DE IMU (Acelerómetro + Giroscopio)
# ═══════════════════════════════════════════════════════════

class IMUSimulator:
    """
    Simula datos de un sensor IMU montado en un vehículo.

    Valores base (conducción normal en ciudad):
      - acc_x: ±0.5 m/s² (lateral, curvas suaves)
      - acc_y: ±0.3 m/s² (vertical, baches)
      - acc_z: 9.8 ± 0.5 m/s² (gravedad + vibraciones)
      - gyro_x: ±5 °/s (giro en curvas)

    Eventos bruscos (frenada, aceleración fuerte):
      - Probabilidad: ~5% por lectura
      - acc_x puede llegar a ±4 m/s²
      - gyro_x puede llegar a ±30 °/s
    """

    def __init__(self):
        self.t = 0  # Contador de tiempo interno para variación suave

    def generate(self):
        """Genera una lectura simulada del IMU."""
        self.t += 1
        es_brusco = random.random() < 0.05  # 5% de probabilidad de evento brusco

        if es_brusco:
            # Evento brusco: frenada, giro agresivo, bache fuerte
            acc_x = random.uniform(-4.0, 4.0)
            acc_y = random.uniform(-3.0, 3.0)
            acc_z = 9.81 + random.uniform(-2.0, 2.0)
            gyro_x = random.uniform(-30.0, 30.0)
        else:
            # Conducción normal con variación suave (usando seno para suavidad)
            base_noise = math.sin(self.t * 0.1) * 0.3
            acc_x = base_noise + random.gauss(0, 0.2)       # Lateral
            acc_y = random.gauss(0, 0.15)                     # Vertical
            acc_z = 9.81 + random.gauss(0, 0.1)              # Gravedad
            gyro_x = math.sin(self.t * 0.05) * 3 + random.gauss(0, 1.0)

        return {
            "acc_x": round(acc_x, 4),
            "acc_y": round(acc_y, 4),
            "acc_z": round(acc_z, 4),
            "gyro_x": round(gyro_x, 4),
            "es_brusco": es_brusco,
        }


# ═══════════════════════════════════════════════════════════
# SIMULADOR DE BPM (Pulsaciones Cardíacas)
# ═══════════════════════════════════════════════════════════

class BPMSimulator:
    """
    Simula las pulsaciones cardíacas de un conductor.

    Rango normal en conducción: 65-90 BPM
    Estrés / evento:            90-120 BPM
    Somnolencia extrema:        50-60 BPM

    La simulación usa un promedio móvil para transiciones suaves.
    """

    def __init__(self):
        self.current_bpm = 72  # BPM base
        self.target_bpm = 72

    def generate(self):
        """Genera una lectura simulada de BPM."""
        # Cambiar target periódicamente
        if random.random() < 0.15:  # 15% de probabilidad de cambiar estado
            estado = random.choices(
                ["normal", "estres", "relajado"],
                weights=[0.6, 0.25, 0.15],
                k=1
            )[0]

            if estado == "normal":
                self.target_bpm = random.randint(68, 85)
            elif estado == "estres":
                self.target_bpm = random.randint(90, 115)
            else:  # relajado
                self.target_bpm = random.randint(55, 65)

        # Transición suave hacia el target
        diff = self.target_bpm - self.current_bpm
        self.current_bpm += diff * 0.2 + random.gauss(0, 1.5)
        self.current_bpm = max(45, min(130, self.current_bpm))

        return {
            "pulsaciones": round(self.current_bpm),
        }


# ═══════════════════════════════════════════════════════════
# FUNCIONES DE IA (YOLO)
# ═══════════════════════════════════════════════════════════

def build_detections(results):
    """
    Extrae las detecciones del resultado de YOLO y las convierte
    al formato esperado por el endpoint.
    Solo incluye detecciones de malos hábitos.
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


def frame_to_jpeg_bytes(frame):
    """Codifica un frame de OpenCV a bytes JPEG."""
    success, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
    if not success:
        return None
    return buffer.tobytes()


# ═══════════════════════════════════════════════════════════
# HILOS DE SENSORES
# ═══════════════════════════════════════════════════════════

def imu_thread(endpoint_url, intervalo, counters):
    """
    Hilo que envía datos de IMU simulados al backend.
    """
    simulator = IMUSimulator()
    print("[IMU] Simulador de IMU iniciado.")

    while not stop_event.is_set():
        datos = simulator.generate()
        status, response = send_event_json(endpoint_url, "IMU", datos)

        counters["imu_sent"] += 1
        brusco_tag = " ⚠ BRUSCO" if datos["es_brusco"] else ""

        if status and 200 <= status < 300:
            print(
                f"[IMU ✓ #{counters['imu_sent']}] "
                f"acc=({datos['acc_x']:.1f}, {datos['acc_y']:.1f}, {datos['acc_z']:.1f}) "
                f"gyro={datos['gyro_x']:.1f}°/s{brusco_tag}"
            )
        else:
            print(f"[IMU ✗ #{counters['imu_sent']}] {response}")

        stop_event.wait(intervalo)

    print("[IMU] Simulador de IMU detenido.")


def bpm_thread(endpoint_url, intervalo, counters):
    """
    Hilo que envía datos de BPM simulados al backend.
    """
    simulator = BPMSimulator()
    print("[BPM] Simulador de BPM iniciado.")

    while not stop_event.is_set():
        datos = simulator.generate()
        status, response = send_event_json(endpoint_url, "BPM", datos)

        counters["bpm_sent"] += 1
        bpm = datos["pulsaciones"]

        # Indicador visual del rango
        if bpm < 60:
            indicator = "💤"
        elif bpm > 100:
            indicator = "🔴"
        else:
            indicator = "💚"

        if status and 200 <= status < 300:
            print(f"[BPM ✓ #{counters['bpm_sent']}] {indicator} {bpm} BPM")
        else:
            print(f"[BPM ✗ #{counters['bpm_sent']}] {response}")

        stop_event.wait(intervalo)

    print("[BPM] Simulador de BPM detenido.")


# ═══════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════

def main():
    args = parse_args()

    # Construir URL del endpoint
    endpoint_url = f"{args.url}/viajes/{args.viaje}/eventos"

    # Contadores compartidos (thread-safe para operaciones simples en CPython)
    counters = {
        "ia_sent": 0,
        "imu_sent": 0,
        "bpm_sent": 0,
        "frames": 0,
    }

    print("=" * 60)
    print("  FocusTrack AI - Server Completo (IA + Sensores)")
    print("=" * 60)
    print(f"  Modelo:         {args.model}")
    print(f"  Cámara:         {args.camera}")
    print(f"  Confianza:      {args.conf}")
    print(f"  Endpoint:       {endpoint_url}")
    print(f"  Display:        {'Desactivado' if args.no_display else 'Activado'}")
    print(f"  ── Intervalos ──")
    print(f"  IA (cámara):    cada {args.intervalo_ia}s")
    print(f"  IMU (simulado): cada {args.intervalo_imu}s {'(DESACTIVADO)' if args.no_imu else ''}")
    print(f"  BPM (simulado): cada {args.intervalo_bpm}s {'(DESACTIVADO)' if args.no_bpm else ''}")
    print("=" * 60)

    # ── Cargar modelo YOLO ──
    print("\n[INFO] Cargando modelo YOLO...")
    model_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), args.model)
    model = YOLO(model_path)
    print("[INFO] Modelo cargado correctamente.")

    # ── Abrir cámara ──
    print(f"[INFO] Abriendo cámara {args.camera}...")
    cap = cv2.VideoCapture(args.camera)
    if not cap.isOpened():
        print("[ERROR] No se pudo abrir la cámara.")
        sys.exit(1)
    print("[INFO] Cámara abierta correctamente.")

    # ── Lanzar hilos de sensores ──
    threads = []

    if not args.no_imu:
        t_imu = threading.Thread(
            target=imu_thread,
            args=(endpoint_url, args.intervalo_imu, counters),
            daemon=True,
            name="IMU-Simulator"
        )
        threads.append(t_imu)
        t_imu.start()

    if not args.no_bpm:
        t_bpm = threading.Thread(
            target=bpm_thread,
            args=(endpoint_url, args.intervalo_bpm, counters),
            daemon=True,
            name="BPM-Simulator"
        )
        threads.append(t_bpm)
        t_bpm.start()

    print("\n[INFO] Iniciando monitoreo... Presiona 'q' para salir.\n")

    last_ia_send_time = 0

    try:
        while cap.isOpened():
            success, frame = cap.read()
            if not success:
                print("[WARN] No se pudo leer el frame.")
                break

            frame = cv2.flip(frame, 1)
            counters["frames"] += 1

            # Convertir BGR -> RGB para YOLO
            img_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

            # Inferencia
            results = model.predict(
                source=img_rgb,
                conf=args.conf,
                imgsz=640,
                verbose=False
            )

            # Extraer detecciones de malos hábitos
            detections = build_detections(results)

            # Anotar frame para visualización
            annotated_frame = results[0].plot()
            final_frame = cv2.cvtColor(annotated_frame, cv2.COLOR_RGB2BGR)

            # ── Enviar evento IA si hay detecciones y pasó el intervalo ──
            current_time = time.time()
            if detections and (current_time - last_ia_send_time) >= args.intervalo_ia:
                frame_bytes = frame_to_jpeg_bytes(frame)

                if frame_bytes:
                    status, response_text = send_event_ia(
                        endpoint_url, frame_bytes, detections
                    )
                    last_ia_send_time = current_time
                    counters["ia_sent"] += 1

                    det_summary = ", ".join(
                        f"{d['etiqueta']}({d['confianza']:.2f})" for d in detections
                    )
                    if status and 200 <= status < 300:
                        print(
                            f"[IA  ✓ #{counters['ia_sent']}] "
                            f"{det_summary} → HTTP {status}"
                        )
                    else:
                        print(
                            f"[IA  ✗ #{counters['ia_sent']}] "
                            f"{det_summary} → {response_text}"
                        )

            # ── Mostrar ventana de video ──
            if not args.no_display:
                info_text = (
                    f"IA:{counters['ia_sent']} | "
                    f"IMU:{counters['imu_sent']} | "
                    f"BPM:{counters['bpm_sent']} | "
                    f"Det:{len(detections)}"
                )
                cv2.putText(
                    final_frame, info_text,
                    (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.6,
                    (0, 255, 0), 2
                )

                cv2.imshow("FocusTrack AI - Server", final_frame)
                if cv2.waitKey(1) & 0xFF == ord("q"):
                    break

    except KeyboardInterrupt:
        print("\n[INFO] Interrupción por teclado. Cerrando...")

    finally:
        # Detener hilos de sensores
        stop_event.set()
        for t in threads:
            t.join(timeout=3)

        cap.release()
        if not args.no_display:
            cv2.destroyAllWindows()

        print("\n" + "=" * 60)
        print("  📊 Resumen de sesión:")
        print(f"  Frames procesados:    {counters['frames']}")
        print(f"  Eventos IA enviados:  {counters['ia_sent']}")
        print(f"  Eventos IMU enviados: {counters['imu_sent']}")
        print(f"  Eventos BPM enviados: {counters['bpm_sent']}")
        print(f"  Total eventos:        {counters['ia_sent'] + counters['imu_sent'] + counters['bpm_sent']}")
        print("=" * 60)


if __name__ == "__main__":
    main()

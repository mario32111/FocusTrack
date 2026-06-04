"""
FocusTrack IoT - Raspberry Pi Edge Client
=========================================
Captura fotos continuamente usando fswebcam (optimizado para hardware de Raspberry).
Envía cada foto al microservicio api-detection (FastAPI) para inferencia de IA.
Si api-detection detecta un mal hábito, reenvía la foto como evidencia a backend-main.
"""

import os
import time
import argparse
import requests
import json
import subprocess
from datetime import datetime, timezone

# ═══════════════════════════════════════════════════════════
# CONFIGURACIÓN
# ═══════════════════════════════════════════════════════════

RAM_DRIVE_PATH = "/dev/shm/frame_current.jpg"

def parse_args():
    parser = argparse.ArgumentParser(description="FocusTrack IoT - Cliente de Cámara Edge")
    parser.add_argument("--viaje", required=True, help="ID del viaje activo")
    parser.add_argument("--url-backend", default="http://localhost:3000", help="URL base del backend-main")
    parser.add_argument("--url-ia", default="http://localhost:8000", help="URL base del microservicio api-detection")
    parser.add_argument("--intervalo", type=float, default=2.0, help="Segundos entre cada toma de foto")
    return parser.parse_args()


def get_timestamp():
    """Genera un timestamp ISO 8601 en UTC."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# ═══════════════════════════════════════════════════════════
# FUNCIONES DE CAPTURA Y RED
# ═══════════════════════════════════════════════════════════

def capture_frame():
    """
    Captura una foto usando fswebcam y la guarda en la RAM (/dev/shm).
    Retorna True si fue exitoso, False de lo contrario.
    """
    try:
        # Comando optimizado: sin banner, resolucion estándar, salto de primeros frames para enfocar
        cmd = [
            "fswebcam",
            "-r", "640x480",
            "--no-banner",
            "-S", "20",
            "-F", "5",
            RAM_DRIVE_PATH
        ]
        
        # Ocultar la salida en terminal para no ensuciar los logs
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
        return os.path.exists(RAM_DRIVE_PATH)
    except Exception as e:
        print(f"[ERROR] Falla al capturar foto con fswebcam: {e}")
        return False


def request_ia_prediction(url_ia):
    """
    Envía la foto en RAM al microservicio api-detection para saber si hay infracciones.
    Retorna la lista de detecciones (o lista vacía si hubo error o no hay nada).
    """
    endpoint = f"{url_ia}/predict"
    
    try:
        with open(RAM_DRIVE_PATH, "rb") as f:
            files = {"evidencia": ("frame.jpg", f, "image/jpeg")}
            response = requests.post(endpoint, files=files, timeout=5)
            
        if response.status_code == 200:
            data = response.json()
            return data.get("detecciones", [])
        else:
            print(f"[IA-WARN] Error del microservicio: HTTP {response.status_code} - {response.text}")
            return []
    except requests.exceptions.RequestException as e:
        print(f"[IA-ERROR] No se pudo conectar a api-detection: {e}")
        return []
    except Exception as e:
        print(f"[IA-ERROR] Error inesperado consultando a la IA: {e}")
        return []


def send_evidence_to_backend(url_backend, id_viaje, detecciones):
    """
    Envía la foto en RAM a backend-main como evidencia de un mal hábito.
    """
    endpoint = f"{url_backend}/viajes/{id_viaje}/eventos"
    
    data = {
        "tipo": "IA",
        "detecciones": json.dumps(detecciones),
        "timestamp": get_timestamp(),
    }
    
    try:
        with open(RAM_DRIVE_PATH, "rb") as f:
            files = {"evidencia": ("frame.jpg", f, "image/jpeg")}
            response = requests.post(endpoint, files=files, data=data, timeout=10)
            
        if 200 <= response.status_code < 300:
            print(f"[BACKEND-OK] Evidencia subida correctamente. HTTP {response.status_code}")
        else:
            print(f"[BACKEND-WARN] Falló subida de evidencia. HTTP {response.status_code} - {response.text}")
    except requests.exceptions.RequestException as e:
        print(f"[BACKEND-ERROR] No se pudo conectar a backend-main: {e}")


# ═══════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════

def main():
    args = parse_args()

    print("=" * 60)
    print("  FocusTrack IoT - Raspberry Pi Edge Client")
    print("=" * 60)
    print(f"  Viaje ID:         {args.viaje}")
    print(f"  Microservicio IA: {args.url_ia}/predict")
    print(f"  Backend Main:     {args.url_backend}/viajes/{args.viaje}/eventos")
    print(f"  Intervalo:        cada {args.intervalo}s")
    print("=" * 60)
    print("[INFO] Iniciando ciclo de monitoreo... Presiona Ctrl+C para salir.\n")

    frames_tomados = 0
    infracciones_enviadas = 0

    try:
        while True:
            t_inicio = time.time()
            
            # 1. Capturar foto
            if capture_frame():
                frames_tomados += 1
                
                # 2. Consultar al microservicio de IA
                detecciones = request_ia_prediction(args.url_ia)
                
                # 3. Si hay malos hábitos, notificar al backend
                if detecciones:
                    infracciones_enviadas += 1
                    det_summary = ", ".join(f"{d['etiqueta']}({d['confianza']:.2f})" for d in detecciones)
                    print(f"[{datetime.now().strftime('%H:%M:%S')}] 🚨 INFRACCIÓN DETECTADA: {det_summary}")
                    
                    # Enviar evidencia
                    send_evidence_to_backend(args.url_backend, args.viaje, detecciones)
                else:
                    # Opcional: imprimir un punto por cada frame analizado sin infracción
                    print(".", end="", flush=True)

            # Esperar hasta el próximo ciclo
            t_fin = time.time()
            tiempo_restante = args.intervalo - (t_fin - t_inicio)
            if tiempo_restante > 0:
                time.sleep(tiempo_restante)

    except KeyboardInterrupt:
        print("\n[INFO] Interrupción por teclado. Cerrando...")
    finally:
        # Limpiar la memoria RAM
        if os.path.exists(RAM_DRIVE_PATH):
            os.remove(RAM_DRIVE_PATH)
        
        print("\n" + "=" * 60)
        print("  📊 Resumen de sesión:")
        print(f"  Frames capturados:        {frames_tomados}")
        print(f"  Infracciones registradas: {infracciones_enviadas}")
        print("=" * 60)


if __name__ == "__main__":
    main()

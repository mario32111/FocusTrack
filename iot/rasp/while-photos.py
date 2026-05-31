import subprocess
import requests
import json
import time
import os

# Configuración basada en tu entorno actual
API_URL = "http://192.168.15.39:3000/viajes/lIIIVYiHpCFABgHOIqie/eventos"
# Recomendación: Usar la RAM (/dev/shm) para velocidad y cuidar tu SD
FILE_NAME = "/dev/shm/prueba.jpg" 
INTERVALO = 10  # Tiempo en segundos entre cada foto

def capturar_y_enviar():
    try:
        # 1. Captura con los parámetros que te funcionaron bien
        # -F 5 y -S 20 aseguran la calidad que ya lograste
        subprocess.run([
            "fswebcam",
            "-r", "640x480",
            "--no-banner",
            "-F", "5",
            "-S", "20",
            FILE_NAME
        ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        # 2. Leer archivo y enviar (Multipart/form-data)
        if os.path.exists(FILE_NAME):
            with open(FILE_NAME, "rb") as f:
                payload = {
                    'tipo': 'IA',
                    'detecciones': json.dumps([{"etiqueta": "monitoreo_activo", "confianza": 1.0}])
                }
                files = {'evidencia': (FILE_NAME, f, 'image/jpeg')}

                response = requests.post(API_URL, data=payload, files=files, timeout=15)
                print(f"[OK] Foto enviada ({time.strftime('%H:%M:%S')}). Status: {response.status_code}")
            
            # Borramos la foto de la RAM para que la siguiente sea fresca
            os.remove(FILE_NAME)
        else:
            print("[ERROR]: El archivo de imagen no se creó.")

    except Exception as e:
        print(f"[ERROR] en el ciclo: {e}")

if __name__ == "__main__":
    print(f"Iniciando monitoreo constante... (Intervalo: {INTERVALO}s)")
    while True:
        capturar_y_enviar()
        # Espera antes de la siguiente captura
        time.sleep(INTERVALO)

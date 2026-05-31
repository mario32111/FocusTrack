import subprocess
import requests
import json
import time
import os

# Configuración basada en tu entorno actual
API_URL = "http://192.168.1.72:3000/viajes/lIIIVYiHpCFABgHOIqie/eventos"
FILE_NAME = "prueba.jpg"

def capturar_y_enviar():
    try:
        # 1. Captura con salto de cuadros para evitar bandas de colores
        # Usamos -F 5 y -S 20 para estabilizar la imagen en la RPi B+
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

                response = requests.post(API_URL, data=payload, files=files, timeout=10)
                print(f"[OK] Foto enviada. Status: {response.status_code}")
        else:
            print("[ERROR]: El archivo de imagen no se creó.")

    except Exception as e:
        print(f"[ERROR]: {e}")

if __name__ == "__main__":
    capturar_y_enviar()

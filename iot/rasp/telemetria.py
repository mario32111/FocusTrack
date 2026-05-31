import time
import json
import paho.mqtt.client as mqtt
import socket
import ssl
import subprocess
import requests
import os
import threading  # Fundamental para manejar ambos procesos
from mpu6050 import mpu6050

# --- CONFIGURACIÓN ---
MQTT_SERVER = "192.168.1.72"
MQTT_PORT = 8883
MQTT_USER = "juanito"
MQTT_PASS = "hola123"
API_URL = "http://192.168.1.72:3000/viajes/lIIIVYiHpCFABgHOIqie/eventos"
FILE_NAME = "/dev/shm/prueba.jpg"  # Usamos la RAM para no estresar la SD
INTERVALO_FOTOS = 10 

# --- INICIALIZACIÓN DE SENSORES ---
try:
    sensor = mpu6050(0x68)
    print("[OK] Sensor MPU-6050 inicializado")
except Exception as e:
    print(f"[ERROR] MPU-6050: {e}")
    sensor = None

client_id = f"RPI-B-Plus-FocusTrack-{socket.gethostname()}"
topic_telemetria = f"carro/sensores/{client_id}"

# --- FUNCIÓN DE LA CÁMARA (HILO 1) ---
def hilo_fotos():
    print(f"[INFO] Hilo de cámara iniciado (Cada {INTERVALO_FOTOS}s)")
    while True:
        try:
            # 1. Captura con parámetros de calidad para B+
            subprocess.run([
                "fswebcam", "-r", "640x480", "--no-banner",
                "-F", "5", "-S", "20", FILE_NAME
            ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

            # 2. Envío HTTP
            if os.path.exists(FILE_NAME):
                with open(FILE_NAME, "rb") as f:
                    payload = {
                        'tipo': 'IA',
                        'detecciones': json.dumps([{"etiqueta": "monitoreo_activo", "confianza": 1.0}])
                    }
                    files = {'evidencia': (FILE_NAME, f, 'image/jpeg')}
                    response = requests.post(API_URL, data=payload, files=files, timeout=15)
                    print(f"[FOTO] Enviada. Status: {response.status_code}")
                os.remove(FILE_NAME)
        except Exception as e:
            print(f"[ERROR CÁMARA]: {e}")
        
        time.sleep(INTERVALO_FOTOS)

# --- CONFIGURACIÓN MQTT ---
def on_connect(client, userdata, flags, rc, properties=None):
    if rc == 0:
        print("[OK] Conectado al Broker MQTT")
    else:
        print(f"[ERROR] Conexión MQTT fallida: {rc}")

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id)
client.username_pw_set(MQTT_USER, MQTT_PASS)
client.on_connect = on_connect
context = ssl.create_default_context()
context.check_hostname = False
context.verify_mode = ssl.CERT_REQUIRED
client.tls_set_context(context)

# --- EJECUCIÓN PRINCIPAL ---
if __name__ == "__main__":
    # 1. Conectar MQTT
    try:
        client.connect(MQTT_SERVER, MQTT_PORT, 60)
        client.loop_start()
    except Exception as e:
        print(f"[CRÍTICO] Error MQTT: {e}")

    # 2. Lanzar el hilo de las fotos para que no bloquee el MPU
    thread_camara = threading.Thread(target=hilo_fotos, daemon=True)
    thread_camara.start()

    # 3. Bucle Principal: Telemetría MPU-6050 (HILO PRINCIPAL)
    print("[INFO] Iniciando transmisión de telemetría...")
    try:
        while True:
            if sensor:
                accel = sensor.get_accel_data()
                gyro = sensor.get_gyro_data()
                payload = {
                    "acelerometro": {"x": round(accel['x'], 2), "y": round(accel['y'], 2), "z": round(accel['z'], 2)},
                    "giroscopio": {"x": round(gyro['x'], 2), "y": round(gyro['y'], 2), "z": round(gyro['z'], 2)}
                }
            else:
                payload = {"error": "Sensor no disponible"}

            client.publish(topic_telemetria, json.dumps(payload))
            time.sleep(0.5)  # Frecuencia de 2Hz para telemetría

    except KeyboardInterrupt:
        print("\n[INFO] Deteniendo FocusTrack...")
        client.loop_stop()
        client.disconnect()

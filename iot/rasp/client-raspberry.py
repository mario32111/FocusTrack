import os
import time
import argparse
import requests
import json
import threading
import paho.mqtt.client as mqtt
import ssl
import socket
import subprocess
from mpu6050 import mpu6050
from datetime import datetime, timezone

# Global flag to stop threads
stop_event = threading.Event()

# Configuration Constants
RAM_DRIVE_PATH = "/dev/shm/frame_current.jpg"

def parse_args():
    parser = argparse.ArgumentParser(description="FocusTrack IoT - RPi Client")
    parser.add_argument("--viaje", required=True, help="ID del viaje activo")
    parser.add_argument("--url-backend", default="http://localhost:3000", help="URL base del backend-main")
    parser.add_argument("--mqtt-server", default="192.168.137.1", help="Broker MQTT")
    parser.add_argument("--mqtt-port", type=int, default=8883, help="Puerto MQTT")
    parser.add_argument("--mqtt-user", default="juanito", help="Usuario MQTT")
    parser.add_argument("--mqtt-pass", default="hola123", help="Password MQTT")
    parser.add_argument("--intervalo-cam", type=float, default=2.0, help="Intervalo cámara")
    return parser.parse_args()

# --- Hilo 1: Cámara ---
def camera_loop(args):
    print("[CAM] Iniciando hilo de cámara")
    while not stop_event.is_set():
        try:
            # Capture using fswebcam (original command)
            cmd = ["fswebcam", "-r", "640x480", "--no-banner", "-S", "20", "-F", "5", RAM_DRIVE_PATH]
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
            
            # Post to backend-main/ingest-frame
            if os.path.exists(RAM_DRIVE_PATH):
                with open(RAM_DRIVE_PATH, "rb") as f:
                    files = {"frame": ("frame.jpg", f, "image/jpeg")}
                    try:
                        requests.post(f"{args.url_backend}/ingest-frame", files=files, timeout=5)
                    except Exception as e:
                        print(f"[CAM-ERROR] Error enviando a backend: {e}")
        except Exception as e:
            print(f"[CAM-ERROR] Error en captura: {e}")
        time.sleep(args.intervalo_cam)

# --- Hilo 2: Sensores (MPU) ---
def sensor_loop(args):
    print("[SENSOR] Iniciando hilo de sensores")
    # MQTT setup
    client_id = f"RPI-B-Plus-FocusTrack-{socket.gethostname()}"
    topic = f"carro/sensores/{client_id}"
    
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id)
    client.username_pw_set(args.mqtt_user, args.mqtt_pass)
    
    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_REQUIRED
    client.tls_set_context(context)
    
    try:
        client.connect(args.mqtt_server, args.mqtt_port, 60)
        client.loop_start()
    except Exception as e:
        print(f"[SENSOR-CRITICAL] Error MQTT: {e}")
        return

    # MPU setup
    try:
        sensor = mpu6050(0x68)
    except Exception as e:
        print(f"[SENSOR-ERROR] MPU init failed: {e}")
        sensor = None

    while not stop_event.is_set():
        if sensor:
            accel = sensor.get_accel_data()
            gyro = sensor.get_gyro_data()
            payload = {
                "acelerometro": accel,
                "giroscopio": gyro
            }
            client.publish(topic, json.dumps(payload))
        time.sleep(0.5)
    
    client.loop_stop()
    client.disconnect()

def main():
    args = parse_args()
    
    t1 = threading.Thread(target=camera_loop, args=(args,))
    t2 = threading.Thread(target=sensor_loop, args=(args,))
    
    t1.start()
    t2.start()
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("[INFO] Cerrando...")
        stop_event.set()
        t1.join()
        t2.join()

if __name__ == "__main__":
    main()

import time
import json
import paho.mqtt.client as mqtt
import socket
import ssl
from mpu6050 import mpu6050 # Importar la librería del sensor

# --- CONFIGURACIÓN ---
MQTT_SERVER = "192.168.137.1"
MQTT_PORT = 8883
MQTT_USER = "juanito"
MQTT_PASS = "hola123"

# Inicializar sensor MPU-6050 (Dirección 0x68 que confirmamos con i2cdetect)
try:
    sensor = mpu6050(0x68)
    print("[OK] Sensor MPU-6050 inicializado correctamente")
except Exception as e:
    print(f"[ERROR] No se pudo inicializar el sensor: {e}")
    sensor = None

# Generar ID único
client_id = f"RPI-B-Plus-FocusTrack-{socket.gethostname()}"
topic = f"carro/sensores/{client_id}"

def on_connect(client, userdata, flags, rc, properties=None):
    if rc == 0:
        print(f"[OK] Conectado al broker MQTT (Telemetría Real)")
    else:
        print(f"[ERROR] Fallo en conexión, código: {rc}")

# --- CONFIGURACIÓN DEL CLIENTE (Tu base funcional) ---
client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id)
client.username_pw_set(MQTT_USER, MQTT_PASS)
client.on_connect = on_connect

# Contexto SSL estable
context = ssl.create_default_context()
context.check_hostname = False
context.verify_mode = ssl.CERT_REQUIRED
client.tls_set_context(context)

print(f"Intentando conectar a {MQTT_SERVER}...")
try:
    client.connect(MQTT_SERVER, MQTT_PORT, 60)
    client.loop_start()
except Exception as e:
    print(f"[CRÍTICO] Fallo de conexión inicial: {e}")

try:
    while True:
        if sensor:
            # Leer datos reales del acelerómetro y giroscopio
            # Estos son los datos clave para tu especialidad en Data Science
            accel_data = sensor.get_accel_data()
            gyro_data = sensor.get_gyro_data()
            
            # Construir el JSON con la telemetría del FocusTrack
            payload = {
                "acelerometro": {
                    "x": round(accel_data['x'], 2),
                    "y": round(accel_data['y'], 2),
                    "z": round(accel_data['z'], 2)
                },
                "giroscopio": {
                    "x": round(gyro_data['x'], 2),
                    "y": round(gyro_data['y'], 2),
                    "z": round(gyro_data['z'], 2)
                }
            }
        else:
            payload = {"error": "Sensor MPU-6050 no detectado"}

        # Publicar telemetría
        print(f"Transmitiendo a {topic}")
        client.publish(topic, json.dumps(payload))

        # 0.5 segundos (500ms) es el estándar para detectar anomalías de manejo
        time.sleep(0.5)

except KeyboardInterrupt:
    print("\nDeteniendo FocusTrack...")
    client.loop_stop()
    client.disconnect()


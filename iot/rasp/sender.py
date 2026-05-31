import time
import json
import random
import paho.mqtt.client as mqtt
from paho.mqtt import enums
import socket
import ssl

# --- CONFIGURACIÓN ---
MQTT_SERVER = "192.168.1.72"
MQTT_PORT = 8883
MQTT_USER = "juanito"
MQTT_PASS = "hola123"

# Generar un ID único similar al del ESP32 usando el nombre del equipo
client_id = f"RPI-B-Plus-FocusTrack-{socket.gethostname()}"
topic = f"carro/sensores/{client_id}"

def on_connect(client, userdata, flags, rc, properties=None):
    if rc == 0:
        print(f"[OK] Conectado al broker MQTT")
    else:
        print(f"[ERROR] Fallo en conexión, código: {rc}")

# --- CONFIGURACIÓN DEL CLIENTE ---
client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id)
client.username_pw_set(MQTT_USER, MQTT_PASS)
client.on_connect = on_connect

# 1. Crear el contexto SSL usando los certificados del sistema
context = ssl.create_default_context()

# 2. Desactivar la verificación del nombre del host (IP mismatch)
# Esto permite que la IP no coincida con el nombre en el certificado,
# pero sigue validando que el certificado haya sido firmado por tu CA.
context.check_hostname = False
context.verify_mode = ssl.CERT_REQUIRED 

# 3. Aplicar el contexto al cliente
client.tls_set_context(context)

print(f"Intentando conectar a {MQTT_SERVER}...")
try:
    # Nota: No llames a connect dos veces. 
    # El método loop_start() manejará las reconexiones.
    client.connect(MQTT_SERVER, MQTT_PORT, 60)
    client.loop_start() 
except Exception as e:
    print(f"[CRÍTICO] Fallo de conexión inicial: {e}")


try:
    while True:
        # Generar datos ficticios (Igual que en tu ESP32)
        temperatura = round(random.uniform(20.0, 35.0), 1)
        velocidad = random.randint(0, 120)
        
        # Crear el JSON
        payload = {
            "temperatura": temperatura,
            "velocidad": velocidad
        }
        
        # Publicar
        print(f"Enviando a {topic}: {payload}")
        client.publish(topic, json.dumps(payload))
        
        # Esperar 5 segundos (como tu lastMsg > 5000)
        time.sleep(5)

except KeyboardInterrupt:
    print("\nDeteniendo publicador...")
    client.loop_stop()
    client.disconnect()

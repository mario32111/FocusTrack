import time
import json
import paho.mqtt.client as mqtt
import socket
import ssl
from mpu6050 import mpu6050

# --- CONFIGURACIÓN ---
# ¡IMPORTANTE! Asegúrate de que esta IP sea la de tu máquina donde corre Docker
MQTT_SERVER = "192.168.1.72" # IP CONFIRMADA
MQTT_PORT = 8883
MQTT_USER = "juanito"
MQTT_PASS = "hola123"

# Número de lecturas por batch (10 lecturas = 5 segundos a 2 Hz)
BATCH_SIZE = 10
INTERVAL = 0.5  # 500 ms = 2 Hz, para una frecuencia de 2 Hz

# Inicializar sensor MPU-6050 (Dirección 0x68 que confirmamos con i2cdetect)
try:
    sensor = mpu6050(0x68)
    print("[OK] Sensor MPU-6050 inicializado correctamente")
except Exception as e:
    print(f"[ERROR] No se pudo inicializar el sensor: {e}")
    sensor = None

# Generar ID único para el cliente MQTT (usando el hostname de la Raspberry Pi)
client_id = f"RPI-B-Plus-FocusTrack-{socket.gethostname()}"
# Tema MQTT al que publicaremos los datos del sensor
topic = f"carro/sensores/{client_id}"

def on_connect(client, userdata, flags, rc, properties=None):
    if rc == 0:
        print(f"[OK] Conectado al broker MQTT (Telemetría Real) en {MQTT_SERVER}:{MQTT_PORT}")
    else:
        print(f"[ERROR] Fallo en conexión al broker, código: {rc}")
        # En un entorno de producción, aquí podrías tener lógica para reintentar
        # o notificar de forma más robusta.

# --- CONFIGURACIÓN DEL CLIENTE MQTT ---
client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id)
client.username_pw_set(MQTT_USER, MQTT_PASS)
client.on_connect = on_connect 

# Configuración SSL/TLS para la conexión segura al broker
context = ssl.create_default_context()
# Deshabilita la verificación del hostname (útil para certificados autofirmados)
context.check_hostname = False
# Requiere un certificado de servidor, pero no lo valida contra una CA (para pruebas)
context.verify_mode = ssl.CERT_REQUIRED
# Puedes añadir tu CA si la tienes: context.load_verify_locations("path/to/ca.crt")
client.tls_set_context(context)

print(f"Intentando conectar al broker MQTT en {MQTT_SERVER}:{MQTT_PORT}...")
try:
    client.connect(MQTT_SERVER, MQTT_PORT, 60)
    client.loop_start() # Inicia un hilo para manejar la red MQTT en segundo plano
except Exception as e:
    print(f"[CRÍTICO] Fallo de conexión inicial: {e}")
    # En caso de fallo crítico, podríamos querer salir o entrar en modo de recuperación
    exit(1) # Salir del script si no se puede conectar al inicio

# --- BUCLE PRINCIPAL CON BUFFER ---
try:
    readings_batch = [] # Lista para acumular las lecturas del sensor

    while True:
        if sensor:
            # Leer datos reales del acelerómetro y giroscopio
            accel_data = sensor.get_accel_data()
            gyro_data = sensor.get_gyro_data()

            # Formato exacto que espera el modelo de IA (los 6 valores crudos)
            reading = {
                "GyroX": round(gyro_data['x'], 2),
                "GyroY": round(gyro_data['y'], 2),
                "GyroZ": round(gyro_data['z'], 2),
                "AccX": round(accel_data['x'], 2),
                "AccY": round(accel_data['y'], 2),
                "AccZ": round(accel_data['z'], 2)
            }
            
            readings_batch.append(reading) # Añadir la lectura al buffer

            # Cuando el buffer alcanza el tamaño BATCH_SIZE (10 lecturas), enviamos el lote
            if len(readings_batch) == BATCH_SIZE:
                payload = {"readings": readings_batch} # Formato JSON con clave "readings"
                print(f"Transmitiendo lote de {BATCH_SIZE} lecturas a {topic}")
                # Publicar el lote completo como una cadena JSON
                client.publish(topic, json.dumps(payload))
                
                # Limpiamos el buffer para acumular las siguientes 10 lecturas
                readings_batch = [] 
        else:
            # Si el sensor no se inicializó, publicamos un mensaje de error
            payload = {"error": "Sensor MPU-6050 no detectado"}
            print(f"Transmitiendo error a {topic}")
            client.publish(topic, json.dumps(payload))
            time.sleep(5) # Esperar más tiempo antes de reintentar si hay un error del sensor
            continue # Saltamos el delay normal para evitar sleeps dobles

        # Pausa para alcanzar la frecuencia de muestreo de 2 Hz (500 ms)
        time.sleep(INTERVAL)

except KeyboardInterrupt:
    print("\nDeteniendo FocusTrack...")
    client.loop_stop()    # Detiene el hilo de red MQTT
    client.disconnect() # Desconecta del broker MQTT

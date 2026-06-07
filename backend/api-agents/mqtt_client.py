import json
import ssl
import paho.mqtt.client as mqtt
import threading

BROKER = "mosquitto"
PORT = 8883
USERNAME = "mario"
PASSWORD = "admin123"
CA_CERT = "certs/ca.crt"

on_alert_callback = None

def on_connect(client, userdata, flags, rc):
    print(f"[MQTT] Conectado al broker (rc={rc})")
    client.subscribe("alertas/#")
    client.subscribe("carro/sensores/#")

def on_message(client, userdata, msg):
    try:
        data = json.loads(msg.payload.decode())
        if "alertas" in msg.topic and on_alert_callback:
            on_alert_callback(data)
        else:
            print(f"[MQTT] Mensaje en {msg.topic}")
    except Exception as e:
        print(f"[MQTT] Error procesando mensaje: {e}")

def create_client():
    client = mqtt.Client()
    client.tls_set(ca_certs=CA_CERT, tls_version=ssl.PROTOCOL_TLSv1_2)
    client.tls_insecure_set(True)
    client.username_pw_set(USERNAME, PASSWORD)
    client.on_connect = on_connect
    client.on_message = on_message
    return client

def start_mqtt_background(callback):
    global on_alert_callback
    on_alert_callback = callback
    try:
        client = create_client()
        client.connect(BROKER, PORT, 60)
        thread = threading.Thread(target=client.loop_forever, daemon=True)
        thread.start()
        print("[MQTT] Cliente MQTT iniciado en background")
        return client
    except Exception as e:
        print(f"[MQTT] No se pudo conectar al broker: {e}")
        print("[MQTT] El servicio funcionará sin MQTT. Reconectará cuando el broker esté disponible.")
        return None

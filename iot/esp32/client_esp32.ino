#include <WiFi.h>
#include <PubSubClient.h>
#include <WiFiClientSecure.h>
#include <ArduinoJson.h>

// WiFi Configuration
const char* ssid = "INFINITUM7z8t";
const char* password = "963ffc39a2";
const char* mqtt_server = "192.168.1.72";
const int mqtt_port = 8883;
const char* mqtt_user = "mario";
const char* mqtt_pass = "admin123";

WiFiClientSecure espClient;
PubSubClient client(espClient);

unsigned long lastMsg = 0;
String globalClientId = "";
String actionTopic = "";

// Pattern pins
const int VIBRATOR_PIN = 23;

void callback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Mensaje recibido [");
  Serial.print(topic);
  Serial.print("] ");

  char msgBuffer[512];
  unsigned int copyLen = length < sizeof(msgBuffer) - 1 ? length : sizeof(msgBuffer) - 1;
  memcpy(msgBuffer, payload, copyLen);
  msgBuffer[copyLen] = '\0';

  StaticJsonDocument<512> doc;
  DeserializationError err = deserializeJson(doc, msgBuffer, copyLen);

  if (err) {
    Serial.print("Error parseando JSON: ");
    Serial.println(err.c_str());
    return;
  }

  if (!doc.containsKey("accion")) {
    Serial.println("Mensaje ignorado: sin campo 'accion'");
    return;
  }

  const char* accion = doc["accion"];
  if (accion == nullptr) {
    Serial.println("Campo 'accion' nulo");
    return;
  }

  if (strcmp(accion, "vibrar") == 0) {
    int duracion = doc["parametros"]["duracion_ms"] | 500;
    Serial.print("Actuando: vibrar por ");
    Serial.println(duracion);
    digitalWrite(VIBRATOR_PIN, HIGH);
    delay(duracion);
    digitalWrite(VIBRATOR_PIN, LOW);
  } else if (strcmp(accion, "led") == 0) {
    Serial.println("Acción LED recibida");
  } else {
    Serial.print("Acción desconocida: ");
    Serial.println(accion);
  }
}

void setup_wifi() {
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("WiFi Conectado");
}

void reconnect() {
  while (!client.connected()) {
    if (globalClientId == "") {
      globalClientId = "1";
      actionTopic = "carro/actuadores/" + globalClientId;
    }
    
    if (client.connect(globalClientId.c_str(), mqtt_user, mqtt_pass)) {
      Serial.println("MQTT conectado");
      client.subscribe(actionTopic.c_str());
      Serial.print("Suscrito a: ");
      Serial.println(actionTopic);
    } else {
      delay(5000);
    }
  }
}

void setup() {
  Serial.begin(115200);
  pinMode(VIBRATOR_PIN, OUTPUT);
  setup_wifi();
  espClient.setInsecure();
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);
  randomSeed(analogRead(0));
}

void loop() {
  if (!client.connected()) {
    reconnect();
  }
  client.loop();

  unsigned long now = millis();
  if (now - lastMsg > 5000) {
    lastMsg = now;

    float bpm = random(60, 100);

    StaticJsonDocument<256> doc;
    doc["tipo"] = "BPM";
    doc["id_viaje"] = "default";
    JsonObject datos = doc.createNestedObject("datos");
    datos["bpm"] = bpm;

    char msg[256];
    serializeJson(doc, msg);
    String topic = "carro/sensores/" + globalClientId;
    client.publish(topic.c_str(), msg);
  }
}

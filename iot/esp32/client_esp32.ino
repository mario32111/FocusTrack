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
  
  StaticJsonDocument<200> doc;
  deserializeJson(doc, payload, length);
  
  const char* evento = doc["evento"];
  Serial.println(evento);

  if (evento != nullptr) {
    if (strcmp(evento, "MANIOBRA_PELIGROSA") == 0) {
      Serial.println("Actuando: MANIOBRA_PELIGROSA");
      // Pattern A
      digitalWrite(VIBRATOR_PIN, HIGH);
      delay(500);
      digitalWrite(VIBRATOR_PIN, LOW);
      delay(200);
      digitalWrite(VIBRATOR_PIN, HIGH);
      delay(500);
      digitalWrite(VIBRATOR_PIN, LOW);
    } else if (strcmp(evento, "FATIGA_DETECTADA") == 0) {
      Serial.println("Actuando: FATIGA_DETECTADA");
      // Pattern B
      digitalWrite(VIBRATOR_PIN, HIGH);
      delay(2000);
      digitalWrite(VIBRATOR_PIN, LOW);
    }
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
      globalClientId = "ESP32S3-FocusTrack-";
      globalClientId += String(random(0xffff), HEX);
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
  if (now - lastMsg > 5000) { // Telemetry frequency
    lastMsg = now;
    
    // Mock heart rate sensor reading
    float bpm = random(60, 100);
    
    char msg[100];
    snprintf(msg, 100, "{\"bpm\": %.1f}", bpm);
    String topic = "carro/sensores/" + globalClientId;
    client.publish(topic.c_str(), msg);
  }
}

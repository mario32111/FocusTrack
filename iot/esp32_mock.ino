#include <WiFi.h>
#include <PubSubClient.h>

#include <WiFiClientSecure.h>

const char* ssid = "INFINITUM7z8t";
const char* password = "963ffc39a2";
const char* mqtt_server = "192.168.1.72";
const int mqtt_port = 8883;

WiFiClientSecure espClient;
PubSubClient client(espClient);

unsigned long lastMsg = 0;
String globalClientId = ""; // Variable global para guardar el ID único
#define MSG_BUFFER_SIZE (100) // Aumentado para seguridad con el JSON
char msg[MSG_BUFFER_SIZE];

void setup_wifi() {
  Serial.println("\nIntentando conectar al WiFi...");
  WiFi.begin(ssid, password);

  int intentos = 0;
  while (WiFi.status() != WL_CONNECTED && intentos < 20) {
    delay(500);
    Serial.print(".");
    intentos++;
  }

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("\n[ERROR] No se pudo conectar. ¡Revisa tu contraseña!");
  } else {
    Serial.println("\n[OK] WiFi Conectado");
  }
}

void reconnect() {
  while (!client.connected()) {
    Serial.print("Intentando conexión MQTT...");
    // Generar el clientId solo la primera vez si está vacío
    if (globalClientId == "") {
      globalClientId = "ESP32S3-FocusTrack-";
      globalClientId += String(random(0xffff), HEX);
    }
    
    // Conectar usando usuario y contraseña
    const char* mqtt_user = "mario";
    const char* mqtt_pass = "admin123";

    if (client.connect(globalClientId.c_str(), mqtt_user, mqtt_pass)) {
      Serial.println("conectado");
    } else {
      Serial.print("falló, rc=");
      Serial.print(client.state());
      Serial.println(" intentando de nuevo en 5 segundos");
      delay(5000);
    }
  }
}

void setup() {
  // --- AJUSTE CRÍTICO PARA ESP32-S3 ---
  Serial.begin(115200);
  
  // Espera a que el puerto USB Serial esté listo (máximo 4 seg)
  unsigned long start = millis();
  while (!Serial && (millis() - start) < 4000) {
    delay(10);
  }
  
  Serial.println("\n[SISTEMA OK]");
  // ------------------------------------

  setup_wifi();
  
  espClient.setInsecure();
  
  client.setServer(mqtt_server, mqtt_port);
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

    float temperatura_ficticia = random(200, 350) / 10.0;
    int velocidad_ficticia = random(0, 120);

    snprintf(msg, MSG_BUFFER_SIZE, "{\"temperatura\": %.1f, \"velocidad\": %d}", temperatura_ficticia, velocidad_ficticia);
    
    // Crear un tema único usando el ID único del ESP32
    String topic = "carro/sensores/" + globalClientId;

    Serial.print("Enviando a MQTT (tema: ");
    Serial.print(topic);
    Serial.print("): ");
    Serial.println(msg);
    
    client.publish(topic.c_str(), msg);
  }
}
#include <WiFi.h>
#include <HTTPClient.h>
#include "esp_camera.h"

// ==========================================
// CONFIGURACIÓN DE RED Y API
// ==========================================
const char* ssid = "INFINITUM7z8t";
const char* password = "963ffc39a2";

// ¡MUY IMPORTANTE! "localhost" no funciona en el ESP32, porque "localhost" es el propio ESP32.
// Debes usar la IP de tu computadora (192.168.1.72) y si el puerto 3000 de tu API no tiene SSL, debe ser http://
const String api_url = "http://192.168.1.72:3000/viajes/lIIIVYiHpCFABgHOIqie/eventos"; 

// ==========================================
// CONFIGURACIÓN DE PINES PARA ESP32-S3 WROOM (Modelo Freenove / Genérico)
// ==========================================
#define PWDN_GPIO_NUM     -1
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM     15
#define SIOD_GPIO_NUM     4
#define SIOC_GPIO_NUM     5

#define Y9_GPIO_NUM       16
#define Y8_GPIO_NUM       17
#define Y7_GPIO_NUM       18
#define Y6_GPIO_NUM       12
#define Y5_GPIO_NUM       10
#define Y4_GPIO_NUM       8
#define Y3_GPIO_NUM       9
#define Y2_GPIO_NUM       11
#define VSYNC_GPIO_NUM    6
#define HREF_GPIO_NUM     7
#define PCLK_GPIO_NUM     13

void setup_wifi() {
  Serial.println("\nConectando al WiFi...");
  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\n[OK] WiFi Conectado");
}

bool init_camera() {
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 10000000; 
  config.frame_size = FRAMESIZE_VGA; 
  config.pixel_format = PIXFORMAT_JPEG; 
  config.grab_mode = CAMERA_GRAB_WHEN_EMPTY;
  config.fb_location = CAMERA_FB_IN_PSRAM;
  config.jpeg_quality = 12;
  config.fb_count = 1;

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Error al iniciar cámara: 0x%x\n", err);
    return false;
  }
  return true;
}

void uploadPhoto() {
  Serial.println("\n--- Encendiendo cámara para capturar foto ---");
  // 1. Iniciar la cámara SOLO cuando se necesita
  if (!init_camera()) {
    return;
  }

  // Darle un segundo a la cámara para ajustar el brillo/balance de blancos
  delay(1000); 

  // 2. Tomar una foto
  camera_fb_t * fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("Error al capturar la foto");
    esp_camera_deinit(); // Apagar cámara si falla
    return;
  }

  Serial.println("Foto capturada. Preparando para enviar...");

  // Definir el boundary para el multipart/form-data
  String boundary = "----ESP32FocusTrackBoundary";

  // Parte 1 del cuerpo
  String bodyPart1 = "--" + boundary + "\r\n";
  bodyPart1 += "Content-Disposition: form-data; name=\"tipo\"\r\n\r\n";
  bodyPart1 += "IA\r\n";
  
  bodyPart1 += "--" + boundary + "\r\n";
  bodyPart1 += "Content-Disposition: form-data; name=\"detecciones\"\r\n\r\n";
  bodyPart1 += "[{\"etiqueta\":\"rostro_detectado\", \"confianza\": 0.99}]\r\n"; 
  
  bodyPart1 += "--" + boundary + "\r\n";
  bodyPart1 += "Content-Disposition: form-data; name=\"evidencia\"; filename=\"foto.jpg\"\r\n";
  bodyPart1 += "Content-Type: image/jpeg\r\n\r\n";

  // Parte 2 del cuerpo
  String bodyPart2 = "\r\n--" + boundary + "--\r\n";

  size_t totalLength = bodyPart1.length() + fb->len + bodyPart2.length();

  WiFiClient client;
  Serial.println("Conectando al servidor...");
  
  if (!client.connect("192.168.1.72", 3000)) {
    Serial.println("Error: No se pudo conectar al servidor Node.js");
    esp_camera_fb_return(fb);
    esp_camera_deinit(); // Apagar cámara
    return;
  }

  Serial.println("Conectado! Enviando headers...");

  client.println("POST /viajes/lIIIVYiHpCFABgHOIqie/eventos HTTP/1.1");
  client.println("Host: 192.168.1.72:3000");
  client.println("Content-Type: multipart/form-data; boundary=" + boundary);
  client.print("Content-Length: ");
  client.println(totalLength);
  client.println(); 

  Serial.println("Enviando foto (Streaming)...");
  client.print(bodyPart1);

  uint8_t *fbBuf = fb->buf;
  size_t fbLen = fb->len;
  for (size_t n = 0; n < fbLen; n += 1024) {
    if (n + 1024 < fbLen) {
      client.write(fbBuf, 1024);
      fbBuf += 1024;
    } else {
      client.write(fbBuf, fbLen % 1024);
    }
  }

  client.print(bodyPart2);
  Serial.println("Payload enviado. Esperando respuesta...");

  while (client.connected()) {
    String line = client.readStringUntil('\n');
    if (line == "\r") { 
      break;
    }
  }
  
  String response = client.readString();
  Serial.println("\n--- Respuesta de la API ---");
  Serial.println(response);
  Serial.println("---------------------------\n");

  client.stop();

  // 3. Liberar foto y APAGAR LA CÁMARA POR COMPLETO
  esp_camera_fb_return(fb);
  esp_camera_deinit(); 
  Serial.println("Cámara APAGADA para evitar sobrecalentamiento.");
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  setup_wifi();
  // NOTA: Ya no iniciamos la cámara en el setup.
}

void loop() {
  // Subir una foto cada 30 segundos a modo de prueba
  uploadPhoto();
  delay(30000);
}

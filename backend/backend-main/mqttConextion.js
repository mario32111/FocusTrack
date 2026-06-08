const mqtt = require("mqtt");
const fs = require("fs");
const path = require("path");
const viajesService = require('./services/viajesService');

// URLs de microservicios
const API_MANIOBRAS_URL = "http://api_maniobras:8000";
const API_DETECTION_URL = "http://api_detection:8000";

// Configurar MQTT con TLS (MQTTS)
const brokerUrl = 'mqtts://mosquitto:8883';
const options = {
  username: 'mario',
  password: 'admin123',
  rejectUnauthorized: false,
  ca: [fs.readFileSync(path.join(__dirname, 'certs', 'ca.crt'))]
};
const mqttClient = mqtt.connect(brokerUrl, options);

// Funciones de enrutamiento
async function routeData(topic, data) {
    if (topic.includes('imu')) {
        // Enviar a api-maniobras
        await fetch(`${API_MANIOBRAS_URL}/predict-latest`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ readings: data.readings }),
        });
    } else if (topic.includes('camara')) {
        // Enviar a api-detection
        await fetch(`${API_DETECTION_URL}/predict`, {
            method: "POST",
            body: JSON.stringify(data), 
        });
    } else if (data.tipo === 'BPM') {
        // Persistir en Firestore
        await viajesService.crearEventoViaje(data.id_viaje, {
            tipo: 'BPM',
            datos: { pulsaciones: data.bpm },
            timestamp: new Date()
        });
    }
}

function conectionMqtt() {
  mqttClient.on('connect', () => {
    console.log('Conectado al broker MQTT');
    mqttClient.subscribe('carro/sensores/#');
  });

  mqttClient.on('message', async (topic, message) => {
    try {
      const data = JSON.parse(message.toString());
      await routeData(topic, data);
    } catch (error) {
      console.error(`Error procesando mensaje en ${topic}:`, error);
    }
  });

  mqttClient.on("error", (err) => {
    console.error("Error de conexión MQTT:", err.message || err);
  });

  return mqttClient;
}

module.exports = conectionMqtt;

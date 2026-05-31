const mqtt = require("mqtt");
const fs = require("fs");
const path = require("path");

// URL del microservicio de maniobras (nombre del contenedor en Docker)
const API_MANIOBRAS_URL = "http://api_maniobras:8000";

// Configurar MQTT con TLS (MQTTS)
const brokerUrl = 'mqtts://mosquitto:8883';
const options = {
  username: 'mario',
  password: 'admin123',
  rejectUnauthorized: false,
  ca: [fs.readFileSync(path.join(__dirname, 'certs', 'ca.crt'))]
};
const mqttClient = mqtt.connect(brokerUrl, options);

// Función para enviar batch al API de maniobras
async function sendToManiobrasAPI(readings) {
  try {
    const response = await fetch(`${API_MANIOBRAS_URL}/predict-latest`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ readings }),
    });

    if (!response.ok) {
      console.error(`[API-MANIOBRAS] Error HTTP: ${response.status}`);
      return null;
    }

    const result = await response.json();
    return result;
  } catch (error) {
    console.error(`[API-MANIOBRAS] Error de conexión: ${error.message}`);
    return null;
  }
}

function conectionMqtt() {
  mqttClient.on('connect', () => {
    console.log('Conectado al broker MQTT');

    const topic = 'carro/sensores/#';
    mqttClient.subscribe(topic, (err) => {
      if (err) {
        console.error('Error al suscribirse al tema:', err);
      } else {
        console.log(`Suscrito al tema: ${topic}`);
      }
    });
  });

  mqttClient.on('message', async (topic, message) => {
    const msg = message.toString();

    try {
      const data = JSON.parse(msg);

      // Verificar si es un batch de lecturas (array de readings)
      if (data.readings && Array.isArray(data.readings) && data.readings.length > 0) {
        console.log(`\n[BATCH] Recibido lote de ${data.readings.length} lecturas en ${topic}`);

        // Enviar al API de maniobras para predecir
        const prediccion = await sendToManiobrasAPI(data.readings);

        if (prediccion) {
          console.log(`[PREDICCIÓN] Maniobra detectada: ${prediccion.maniobra} (${prediccion.confianza}%)`);
          console.log(`[PREDICCIÓN] Todas las probabilidades:`, prediccion.todas_las_probabilidades);
        }
      } else {
        // Mensaje individual (formato legacy o de otros sensores)
        console.log(`Mensaje recibido en ${topic}: ${msg}`);
      }
    } catch (error) {
      console.log(`Mensaje recibido en ${topic}: ${msg}`);
    }
  });

  mqttClient.on("error", (err) => {
    console.error("Error de conexión MQTT:", err.message || err);
    if (err.stack) {
      console.error("Stack trace:", err.stack);
    }
  });

  mqttClient.on("reconnect", () => {
    console.log("Intentando reconectar al broker MQTT...");
  });

  mqttClient.on("close", () => {
    console.log("Conexión cerrada con el broker MQTT");
  });

  return mqttClient;
}

module.exports = conectionMqtt;

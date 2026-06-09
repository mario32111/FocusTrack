const mqtt = require("mqtt");
const fs = require("fs");
const path = require("path");
const viajesService = require('./services/viajesService');

// URLs de microservicios
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

async function routeData(topic, data) {
    const id_viaje = data.id_viaje;

    if (data.tipo === 'IMU') {
        try {
            const response = await fetch(`${API_MANIOBRAS_URL}/predict-latest`, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ readings: data.datos }),
            });
            const resultado_ia = await response.json();

            await viajesService.crearEventoViaje(id_viaje, {
                tipo: 'IMU',
                datos: {
                    lecturas_crudas: data.datos,
                    analisis: {
                        clase: resultado_ia.clase,
                        maniobra: resultado_ia.maniobra,
                        confianza: resultado_ia.confianza,
                        todas_las_probabilidades: resultado_ia.todas_las_probabilidades
                    }
                }
            });
        } catch (error) {
            console.error(`[MQTT] Error procesando IMU para viaje ${id_viaje}:`, error.message);
        }
    } else if (data.tipo === 'BPM') {
        try {
            await viajesService.crearEventoViaje(id_viaje, {
                tipo: 'BPM',
                datos: data.datos
            });
        } catch (error) {
            console.error(`[MQTT] Error procesando BPM para viaje ${id_viaje}:`, error.message);
        }
    }
}

function conectionMqtt() {
  mqttClient.on('connect', () => {
    console.log('[MQTT] Conectado al broker MQTT');
    mqttClient.subscribe('carro/sensores/#');
  });

  mqttClient.on('message', async (topic, message) => {
    try {
      const data = JSON.parse(message.toString());
      await routeData(topic, data);
    } catch (error) {
      console.error(`[MQTT] Error procesando mensaje en ${topic}:`, error.message);
    }
  });

  mqttClient.on("error", (err) => {
    console.error("[MQTT] Error de conexión:", err.message || err);
  });

  return mqttClient;
}

module.exports = conectionMqtt;

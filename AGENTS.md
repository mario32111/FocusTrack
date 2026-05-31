# Guía para Agentes (IA) - FocusTrack Monorepo

Este documento contiene el contexto crítico del repositorio para evitar errores comunes y acelerar el desarrollo.

## Arquitectura del Monorepo
El proyecto es un monorepo que se divide en tres áreas principales:

1. **`backend/`**: Contiene los microservicios y la API principal, orquestados mediante Docker Compose.
2. **`ia/`**: Modelos de Inteligencia Artificial, Jupyter Notebooks, Datasets y lógica de entrenamiento (YOLO, Scikit-Learn, etc.).
3. **`iot/`**: Código embebido para dispositivos (ESP32 en C++, Raspberry Pi en Python, scripts de sensores y telemetría).

## Microservicios del Backend (`backend/`)
Todos los servicios se orquestan desde `backend/docker-compose.yml`:

1. **`backend/backend-main/` (Node.js/Express)**: La API principal del negocio.
   - **Entrypoint:** `backend/backend-main/bin/www` (usando `npm start`).
   - **Capas:** Las rutas están en `routes/` y la lógica/base de datos en `services/`.
   - **Base de Datos:** Firestore (vía Firebase Admin SDK en `fire.js`). Ver la estructura en `README.md`.
   - **MQTT:** Actúa como cliente MQTTS configurado en `mqttConextion.js`.

2. **`backend/api-detection/` (Python/FastAPI)**: Servicio de detección a través de visión artificial.
   - **Entrypoint:** `backend/api-detection/main.py`.

3. **`backend/api-maniobras/` (Python/FastAPI)**: Servicio de clasificación de maniobras del conductor.
   - **Entrypoint:** `backend/api-maniobras/main.py`.

4. **`backend/api-agents/` (Python/FastAPI + AutoGen)**: Servicio inteligente para orquestar agentes de IA (análisis de datos, reportes).
   - **Entrypoint:** `backend/api-agents/main.py`.
   - **Nota:** Tiene montado el archivo `serviceAccountKey.json` para consultar Firestore directamente.

## Comandos y Ejecución Local
- **Docker Compose:** Se debe usar `docker-compose up --build` **desde la carpeta `backend/`** para levantar todos los servicios (`my_api`, `api_detection`, `api_maniobras`, `api_agents`) y el broker MQTT (`mosquitto`).
- Todos los servicios comparten la red `my_network` y se comunican entre sí usando el nombre del contenedor (ej. `http://my_api:3000`, `http://api_agents:8000`).

## Archivos Sensibles y Entorno (⚠️ ¡Crítico!)
No incluir en commits (el `.gitignore` global ya los gestiona):
1. **`backend/backend-main/serviceAccountKey.json`**: Clave de Firebase. Esencial para que Node.js y `api_agents` funcionen.
2. **`backend/backend-main/certs/` (ca.crt, server.crt, server.key)**: Requeridos para TLS/MQTT.
3. **`backend/backend-main/mosquitto.passwd` y `mosquitto.acl`**: Credenciales de MQTT.
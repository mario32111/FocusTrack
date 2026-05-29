# Guía para Agentes (IA) - FocusTrack Monorepo

Este documento contiene el contexto crítico del repositorio para evitar errores comunes y acelerar el desarrollo.

## Arquitectura y Microservicios
El proyecto es un monorepo compuesto por múltiples microservicios orquestados mediante Docker Compose:

1. **`backend-main/` (Node.js/Express)**: La API principal del negocio.
   - **Entrypoint:** `backend-main/bin/www` (usando `npm start`).
   - **Capas:** Las rutas están en `backend-main/routes/` y la lógica/base de datos en `backend-main/services/`.
   - **Base de Datos:** Firestore (vía Firebase Admin SDK en `backend-main/fire.js`). Ver la estructura en `README.md`.
   - **MQTT:** Actúa como cliente MQTTS configurado en `backend-main/mqttConextion.js`.

2. **`api-detection/` (Python/FastAPI)**: Servicio encargado de la detección a través de visión artificial.
   - **Entrypoint:** `api-detection/main.py`.
   - Expuesto internamente para comunicarse con `backend-main` o recibir eventos.

3. **`api-maniobras/` (Python/FastAPI)**: Servicio encargado de la clasificación de maniobras del conductor.
   - **Entrypoint:** `api-maniobras/main.py`.

4. **`api-agents/` (Python/FastAPI + AutoGen)**: Servicio inteligente encargado de orquestar agentes de IA para análisis de datos, reportes y toma de decisiones.
   - **Entrypoint:** `api-agents/main.py`.
   - **Nota:** Tiene montado el archivo `serviceAccountKey.json` en modo solo lectura (`:ro`) para consultar Firestore directamente.

## Comandos y Ejecución Local
- **Docker Compose:** Se debe usar `docker-compose up --build` desde la raíz para levantar todos los servicios (`my_api`, `api_detection`, `api_maniobras`, `api_agents`) y el broker MQTT (`mosquitto`).
- Todos los servicios comparten la red `my_network`, por lo que se pueden comunicar entre sí usando el nombre del contenedor (ej. `http://my_api:3000`, `http://api_agents:8000`).

## Archivos Sensibles y Entorno (⚠️ ¡Crítico!)
No incluir en commits (deben estar en `.gitignore`):
1. **`backend-main/serviceAccountKey.json`**: Clave de Firebase. La API de Node fallará si no existe (y `api_agents` también lo requiere).
2. **`backend-main/certs/` (ca.crt, server.crt, server.key)**: Requeridos para TLS. El comando Docker para generarlos está en `README.md`. Deben estar dentro de `backend-main/certs/`.
3. **`backend-main/mosquitto.passwd` y `backend-main/mosquitto.acl`**: Credenciales de MQTT.
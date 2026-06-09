# Guía para Agentes (IA) - FocusTrack Monorepo

Este documento contiene el contexto crítico del repositorio para evitar errores comunes y acelerar el desarrollo.

## Arquitectura del Monorepo
El proyecto es un monorepo que se divide en tres áreas principales:

1. **`backend/`**: Microservicios y API principal, orquestados via Docker Compose.
2. **`ia/`**: Modelos de IA, Notebooks, Datasets y lógica de entrenamiento (YOLO, Scikit-Learn).
3. **`iot/`**: Código embebido (ESP32 en C++, Raspberry Pi en Python).

## Microservicios del Backend (`backend/`)
Todos los servicios se orquestan desde `backend/docker-compose.yml`:

### 1. `backend/backend-main/` (Node.js/Express) — Puerto 3000
La API principal del negocio.
- **Entrypoint:** `backend/backend-main/bin/www` (`npm start`)
- **Base de Datos:** Firestore (via Firebase Admin SDK en `fire.js`)
- **Storage:** Firebase Storage (via `fire.js` → `bucket`)
- **MQTT:** Cliente MQTTS en `mqttConextion.js`, suscrito a `carro/sensores/#`

#### Rutas (`routes/`)
| Archivo | Prefijo | Endpoints principales |
|---------|---------|----------------------|
| `empresas.js` | `/empresas` | CRUD completo |
| `usuarios.js` | `/usuarios` | CRUD completo. Crea usuario en Firebase Auth |
| `contactosEmergencia.js` | `/contactos-emergencia` | CRUD completo |
| `conductores.js` | `/conductores` | CRUD. `POST /:idUsuario` vincula a usuario |
| `viajes.js` | `/viajes` | CRUD + sub-colección `eventos` (IMU/BPM/IA) |
| `alertas.js` | `/alertas` | CRUD. Filtrado por `nivel_riesgo` e `id_viaje` |
| `dispositivos.js` | `/dispositivos` | CRUD + `PATCH /:id/heartbeat` |
| `mqtt.js` | `/mqtt` | `/publish`, `/publish-actuator`, `/simulate-sensor` |
| `index.js` | `/` | Render vista index |
| `users.js` | — | **DEAD CODE** (no montado en `app.js`) |

#### Servicios (`services/`)
| Archivo | Propósito |
|---------|-----------|
| `empresasService.js` | CRUD `empresas` |
| `usuariosService.js` | CRUD `usuarios` + Firebase Auth |
| `contactosEmergenciaService.js` | CRUD `contactos_emergencia` |
| `conductoresService.js` | CRUD `conductores`. Join cross-collection por empresa |
| `viajesService.js` | **CEREBRO CENTRAL.** CRUD viajes + eventos. Orquesta api-detection, api-maniobras, y crisis agent |
| `alertasCriticasService.js` | CRUD `alertas_criticas` |
| `dispositivosService.js` | CRUD `dispositivos` |
| `uploadService.js` | Subida de archivos a Firebase Storage |

#### Flujo de Datos IoT (via `mqttConextion.js`)
```
ESP32/RPi → MQTT broker (carro/sensores/#) → mqttConextion.js
  ├─ tipo=IMU → api_maniobras/predict-latest → viajesService (almacena + evalúa riesgo)
  ├─ tipo=BPM → viajesService (almacena directamente)
  └─ Riesgo detectado → api_agents/agent/crisis → actuadores ESP32
```

#### `viajesService.js` — Flujo de Eventos
- **Crear evento:** Recibe de MQTT (IMU/BPM) o HTTP (IA desde RPi)
- **Para IA:** Envía foto a `api-detection/predict` via `undici.FormData` + `Blob` global
- **Para IMU:** Almacena readings raw + análisis de api-maniobras
- **Post-persistencia:** Evalúa riesgo (clases 1-4 IMU, malos hábitos IA)
- **Si hay riesgo:** Notifica a `api_agents/agent/crisis`

### 2. `backend/api-detection/` (Python/FastAPI) — Puerto 8001
Detección de malos hábitos con YOLO.
- **Endpoints:** `POST /predict` (imagen → detecciones)
- **Modelo:** `best2.pt`
- **Malos hábitos:** distraccion, somnolencia, comiendo, sin_cinturon, fumando

### 3. `backend/api-maniobras/` (Python/FastAPI) — Puerto 8002
Clasificación de maniobras del conductor.
- **Endpoints:** `POST /predict` (batch), `POST /predict-latest` (última lectura)
- **Modelo:** `modelo_conduccion_97.pkl` (RandomForest)
- **Clases:** 1=Aceleración brusca, 2=Giro derecha, 3=Giro izquierda, 4=Frenado brusco
- **Bug conocido:** `predict-latest` definido 2 veces (líneas 97 y 144)

### 4. `backend/api-agents/` (Python/FastAPI + AutoGen) — Puerto 8003
Agentes inteligentes para análisis y respuesta a crisis.
- **Endpoints:**
  - `POST /agent/crisis` — Evalúa alerta, activa actuadores si necesario
  - `POST /agent/coach` — Feedback personalizado de conducción
  - `POST /agent/chat` — Chatbot de análisis de flota
  - `GET /agent/history/:id_conductor` — Historial de viajes
- **Agentes:**
  - `crisis_agent.py` — `EvaluadorCrisis` (LLM) + `UsuarioProxy` (tool executor). Activa vibrador/LED
  - `coach_agent.py` — `CoachSeguridad`. Genera retroalimentación
  - `fleet_chatbot_agent.py` — `AnalistaFlota` + `EjecutorDeHerramientas`. Consultas de flota
- **API Client:** `api_client.py` — HTTP a `focustrack-backend-api:3000`
- **MQTT Client:** `mqtt_client.py` — Suscrito a `alertas/#` y `carro/sensores/#`
- **LLM:** OpenRouter via `openrouter/auto`

## Dispositivos IoT

### ESP32 (`iot/esp32/client_esp32.ino`)
- **MQTT:** `192.168.1.72:8883` (TLS), usuario `mario`
- **Publica:** `carro/sensores/1` cada 5s
- **Payload BPM:**
  ```json
  { "tipo": "BPM", "id_viaje": "default", "datos": { "bpm": <60-100> } }
  ```
- **Suscribe:** `carro/actuadores/1`
- **Comandos:** `{"accion": "vibrar", "parametros": {"duracion_ms": 1000}}`, `{"accion": "led", "parametros": {"color": "rojo"}}`

### Raspberry Pi (`iot/rasp/client-raspberry.py`)
- **Args:** `--viaje` (requerido), `--url-backend` (default `192.168.1.72:3000`)
- **Dos threads:**
  1. **Cámara:** Captura cada 2s via `fswebcam`, envía `POST /viajes/:id/eventos` con `tipo=IA` + archivo `evidencia`
  2. **IMU:** Lee MPU-6050, buffer de 10 lecturas, publica a `carro/sensores/1`:
     ```json
     { "tipo": "IMU", "id_viaje": "...", "datos": [{ GyroX, GyroY, GyroZ, AccX, AccY, AccZ }, ...] }
     ```

## Comandos y Ejecución
- **Docker Compose:** `docker-compose up --build` desde `backend/`
- **Red:** Todos en `my_network`. Comunicación via nombre de contenedor
- **Puertos host:** 3000 (API), 8001 (detection), 8002 (maniobras), 8003 (agents)

## Archivos Sensibles (⚠️ No commitear)
1. `backend/backend-main/serviceAccountKey.json` — Firebase Admin SDK
2. `backend/backend-main/certs/` — TLS (ca.crt, server.crt, server.key)
3. `backend/backend-main/mosquitto.passwd` y `mosquitto.acl` — Credenciales MQTT
4. `backend/api-agents/.env` — `OPENROUTER_API_KEY` para LLM

## Autenticación
- **Firebase Auth** se usa para usuarios del backend (`usuariosService.js`)
- **MQTT** usa usuario/contraseña simple (`mosquitto.passwd`)
- **Dispositivos** se identifican por `id_dispositivo` en payload y topics MQTT

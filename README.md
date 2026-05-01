# Estructura de Base de Datos FocusTrack (Firestore Optimized)

## 1. Colección: `empresas`
*Cada documento representa una empresa. Se eliminan listas de IDs de empleados para evitar límites de 1MB.*
- **ID del Documento:** `empresa_id`
- `nombre`: String
- `fecha_registro`: Timestamp

## 2. Colección: `conductores`
*Incluye datos del contacto de emergencia embebidos para ahorrar lecturas.*
- **ID del Documento:** `id_conductor`
- `empresa_id`: String (Indexado para búsquedas)
- `nombre_completo`: String
- `num_licencia`: String
- `fecha_contratacion`: Timestamp
- `puntaje_seguridad_global`: Number
- `estado_salud_base`: String
- `foto_perfil_url`: String
- **contacto_emergencia**: (Map/Objeto)
    - `nombre`: String
    - `parentesco`: String
    - `telefono`: String

## 3. Colección: `usuarios`
*Manejo de perfiles y credenciales.*
- **ID del Documento:** `uid` (De Firebase Auth)
- `username`: String
- `rol`: String ("admin", "conductor", "flota")
- `id_referencia`: String (id_conductor o empresa_id según rol)

## 4. Colección: `viajes`
*Planificación de trayectos generales.*
- **ID del Documento:** `id_viaje`
- `fecha`: Timestamp
- `hora_estimada`: String
- `tiempo_estimado_min`: Number
- `origen`: GeoPoint/String
- `destino`: GeoPoint/String

## 5. Colección: `sesiones` (Documento Principal de Actividad)
*Contiene datos denormalizados para mostrar en listas sin hacer JOINs.*
- **ID del Documento:** `id_sesion`
- `id_viaje`: String
- `id_conductor`: String
- `nombre_conductor`: String (Denormalizado para UI)
- `fecha`: Timestamp
- `hora_inicio`: Timestamp
- `hora_fin`: Timestamp (null si está activa)
- `puntaje_riesgo_total`: Number
- `estado`: String ("activa", "finalizada")

## 6. Colección: `telemetria`
*Se recomienda usar id_sesion como prefijo o subcolección para queries rápidas.*
- **ID del Documento:** `id_dato` (Auto-generado)
- `id_sesion`: String (Indexado)
- `timestamp`: Timestamp
- `accel`: (Map) {x, y, z}
- `gyro`: (Map) {x, y, z}
- `es_maniobra_brusca`: Boolean

## 7. Colección: `detecciones_ia`
*Registro de eventos detectados por el modelo FocusTrack.*
- **ID del Documento:** `id_deteccion`
- `id_sesion`: String (Indexado)
- `timestamp`: Timestamp
- `etiqueta`: String ("Smoking", "Phone", "Drowsy", "Eating", "Distracted")
- `confianza`: Number (0.0 a 1.0)
- `evidencia_url`: String (Path a Firebase Storage)

## 8. Colección: `ritmo_cardiaco`
*Sincronizado por sesión para análisis de fatiga.*
- **ID del Documento:** `id_lectura`
- `id_sesion`: String (Indexado)
- `timestamp`: Timestamp
- `bpm`: Number

## 9. Colección: `alertas_criticas`
*Eventos que requieren atención inmediata o resumen de riesgo.*
- **ID del Documento:** `id_alerta`
- `id_sesion`: String
- `timestamp`: Timestamp
- `nivel_riesgo`: String ("Bajo", "Medio", "Alto")
- `tipo_alerta`: String
- `descripcion`: String

## 10. Colección: `dispositivos`
- **ID del Documento:** `device_id`
- `id_usuario`: String
- `ultima_conexion`: Timestamp
- `modelo_hardware`: String


### Comando para agregar un nuevo usuario al broker
docker run --rm -v "${PWD}:/mosquitto/config" eclipse-mosquitto sh -c "mosquitto_passwd -b /mosquitto/config/mosquitto.passwd juanito hola123"


### Comando para generar certificados autofirmados

docker run --rm -v "${PWD}:/workspace" -w /workspace node:18-alpine sh -c "apk add --no-cache openssl && mkdir -p certs && cd certs && openssl genrsa -out ca.key 2048 && openssl req -new -x509 -days 3650 -key ca.key -out ca.crt -subj '/CN=FocusTrackCA' && openssl genrsa -out server.key 2048 && openssl req -new -key server.key -out server.csr -subj '/CN=192.168.1.72' && openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 3650"

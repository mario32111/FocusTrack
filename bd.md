# Estructura de Base de Datos: Sistema de Asistencia al Conductor (Normalizada)

[cite_start]Esta arquitectura utiliza un enfoque de **desnormalización selectiva** para Firestore, optimizando el rendimiento de la API y las aplicaciones cliente (App Móvil y Dashboard Web) al reducir el número de lecturas necesarias[cite: 11, 19].

## 1. Colecciones de Entidades Base

### `empresas`

* [cite_start]**`id_empresa`** (Document ID): Identificador único de la organización[cite: 11].
* **`nombre_empresa`**: Nombre legal o comercial de la flotilla[cite: 11].
* **`fecha_registro`**: Timestamp de creación.

### `usuarios`

[cite_start]Centraliza la autenticación y los roles de acceso[cite: 7, 12].

* [cite_start]**`id_usuario`** (Document ID / Firebase Auth UID): Vínculo con el motor de autenticación[cite: 18].
* **`username`**: Nombre de usuario o correo electrónico.
* **`password`**: (Gestionado internamente por Firebase Auth).
* [cite_start]**`rol`**: String (`"conductor"` o `"master"`) para control de acceso[cite: 11, 12].
* **`id_empresa`**: Referencia (FK) a la colección `empresas`.
* **`id_contacto_emergencia`**: Referencia (FK) a la colección `contactos_emergencia`.

### `contactos_emergencia`

* **`id_contacto`** (Document ID).
* [cite_start]**`nombre`**: Nombre completo del contacto[cite: 22].
* **`parentesco`**: Relación con el usuario[cite: 22].
* [cite_start]**`telefono`**: Número telefónico para alertas críticas[cite: 5, 22].

### `conductores`

[cite_start]Extensión del perfil de usuario con datos operativos y de salud[cite: 18].

* **`id_conductor`** (Document ID - mismo que `id_usuario`).
* [cite_start]**`nombre_completo`**: Nombre del operador[cite: 2].
* **`num_licencia`**: Número de identificación de tránsito.
* **`fecha_contratacion`**: Fecha de ingreso a la empresa.
* [cite_start]**`puntaje_seguridad_global`**: KPI calculado a partir de eventos históricos (Score)[cite: 5, 20].
* **`estado_salud_base`**: Notas sobre condiciones físicas preexistentes.
* **`foto_perfil_path`**: URL del recurso almacenado en Firebase Storage.
* **`id_dispositivo`**: Referencia (FK) al hardware asignado en la colección `dispositivos`.

---

## 2. Colecciones de Actividad y Telemetría

### `viajes`

[cite_start]Unifica "Sesiones" y "Viajes" en una sola entidad para mejorar la trazabilidad[cite: 18, 22].

* **`id_viaje`** (Document ID).
* **`id_conductor`**: Referencia (FK) al operador[cite: 18].
* **`id_empresa`**: Denormalizado para permitir filtrado rápido por el perfil "master"[cite: 11].
* **`fecha`**: Fecha de la jornada[cite: 18].
* [cite_start]**`hora_inicio`**: Timestamp de inicio de sesión[cite: 18].
* **`hora_fin`**: Timestamp de cierre de sesión[cite: 18].
* **`tiempo_estimado`**: Duración prevista en minutos.
* **`score_final_viaje`**: Puntaje de riesgo calculado al finalizar[cite: 20, 22].

#### `eventos_viaje` (Sub-colección de `viajes`)

Agrupa cronológicamente los datos de sensores e IA para facilitar la correlación de eventos[cite: 15, 16, 20].

* **`id_evento`** (Document ID).
* [cite_start]**`timestamp`**: Tiempo exacto de la captura[cite: 18].
* **`tipo`**: Categoría del registro (`"IMU"`, `"IA"`, `"BPM"`).
* **`datos`**: Mapa de valores según el tipo:
  * [cite_start]**IMU**: `{acc_x, acc_y, acc_z, gyro_x, es_brusco: boolean}`[cite: 10, 16].
  * **IA**: `{detecciones: [{etiqueta: string, confianza: float}, ...], path_evidencia: string}` — Array de 1 a 6 hábitos detectados por el modelo de reconocimiento facial, cada uno con su nivel de confianza. La imagen de evidencia se almacena en Firebase Storage[cite: 15].
  * [cite_start]**BPM**: `{pulsaciones: integer}`[cite: 6].

### `alertas_criticas`

[cite_start]Eventos que requieren retroalimentación inmediata (actuadores) o reportes de riesgo[cite: 4, 18, 20].

* **`id_alerta`** (Document ID).
* **`id_viaje`**: Vínculo con la sesión de origen.
* **`timestamp`**: Momento de la activación[cite: 18].
* [cite_start]**`nivel_riesgo`**: Categoría de gravedad (`"Bajo"`, `"Medio"`, `"Alto"`)[cite: 4].
* **`tipo_alerta`**: Descripción técnica (ej. "Uso de celular detectado").
* **`descripcion`**: Detalle adicional para auditoría.

---

## 3. Inventario de Hardware

### `dispositivos`

Gestión del ecosistema IoT[cite: 6, 17, 23].

* **`id_dispositivo`** (Document ID - ID físico del ESP32).
* [cite_start]**`id_usuario_asignado`**: Vínculo con el conductor actual[cite: 6].
* [cite_start]**`ultima_conexion`**: Heartbeat para monitoreo de estado del sistema[cite: 11, 23].

---

## Relaciones y Cardinalidades

1. [cite_start]**Empresa (1) : (N) Usuarios**: Una empresa gestiona múltiples operadores y administradores[cite: 11].
2. [cite_start]**Usuario (1) : (1) Conductor**: Extensión de datos biográficos y operativos[cite: 18].
3. [cite_start]**Usuario (1) : (N) Contactos**: Soporte para múltiples contactos de emergencia[cite: 5].
4. [cite_start]**Conductor (1) : (N) Viajes**: Registro histórico de todas las sesiones de manejo[cite: 18].
5. [cite_start]**Viaje (1) : (N) Eventos**: Captura masiva de telemetría y detecciones por segundo[cite: 15, 16, 23].

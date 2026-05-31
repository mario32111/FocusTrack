const { db } = require('../fire');
const uploadService = require('./uploadService');

const COLLECTION = 'viajes';
const SUB_COLLECTION = 'eventos_viaje';

// ========================
// VIAJES (CRUD)
// ========================

/**
 * Crear un nuevo viaje
 */
const crearViaje = async (data) => {
    const viajeData = {
        id_conductor: data.id_conductor,
        id_empresa: data.id_empresa,
        fecha: data.fecha || new Date(),
        hora_inicio: data.hora_inicio || new Date(),
        hora_fin: data.hora_fin || null,
        tiempo_estimado: data.tiempo_estimado || null,
        score_final_viaje: data.score_final_viaje || null,
    };

    const docRef = await db.collection(COLLECTION).add(viajeData);
    return { id_viaje: docRef.id, ...viajeData };
};

/**
 * Obtener todos los viajes
 */
const obtenerViajes = async () => {
    const snapshot = await db.collection(COLLECTION).orderBy('fecha', 'desc').get();
    const viajes = [];
    snapshot.forEach((doc) => {
        viajes.push({ id_viaje: doc.id, ...doc.data() });
    });
    return viajes;
};

/**
 * Obtener viajes por conductor
 */
const obtenerViajesPorConductor = async (idConductor) => {
    const snapshot = await db
        .collection(COLLECTION)
        .where('id_conductor', '==', idConductor)
        .orderBy('fecha', 'desc')
        .get();
    const viajes = [];
    snapshot.forEach((doc) => {
        viajes.push({ id_viaje: doc.id, ...doc.data() });
    });
    return viajes;
};

/**
 * Obtener viajes por empresa
 */
const obtenerViajesPorEmpresa = async (idEmpresa) => {
    const snapshot = await db
        .collection(COLLECTION)
        .where('id_empresa', '==', idEmpresa)
        .orderBy('fecha', 'desc')
        .get();
    const viajes = [];
    snapshot.forEach((doc) => {
        viajes.push({ id_viaje: doc.id, ...doc.data() });
    });
    return viajes;
};

/**
 * Obtener un viaje por su ID
 */
const obtenerViajePorId = async (id) => {
    const doc = await db.collection(COLLECTION).doc(id).get();
    if (!doc.exists) return null;
    return { id_viaje: doc.id, ...doc.data() };
};

/**
 * Actualizar un viaje (ej. cerrar sesión con hora_fin y score_final)
 */
const actualizarViaje = async (id, data) => {
    const docRef = db.collection(COLLECTION).doc(id);
    const doc = await docRef.get();
    if (!doc.exists) return null;
    await docRef.update(data);
    return { id_viaje: id, ...doc.data(), ...data };
};

/**
 * Eliminar un viaje
 */
const eliminarViaje = async (id) => {
    const docRef = db.collection(COLLECTION).doc(id);
    const doc = await docRef.get();
    if (!doc.exists) return null;
    await docRef.delete();
    return { id_viaje: id, mensaje: 'Viaje eliminado correctamente' };
};

// ========================
// EVENTOS DE VIAJE (Sub-colección)
// ========================

/**
 * Crear un evento en un viaje.
 * Soporta todos los tipos: IMU, BPM e IA.
 * 
 * Para tipo "IA" (reconocimiento facial):
 *   - data.detecciones: JSON string o array de [{ etiqueta: string, confianza: float }, ...]
 *   - file: Archivo de multer (imagen de evidencia) - opcional.
 * 
 * Para tipo "IMU":
 *   - data.datos: { acc_x, acc_y, acc_z, gyro_x, es_brusco }
 * 
 * Para tipo "BPM":
 *   - data.datos: { pulsaciones }
 *
 * @param {string}       idViaje  - ID del viaje.
 * @param {Object}       data     - Datos del evento (incluye tipo).
 * @param {Object|null}  file     - Archivo de multer (solo para tipo IA).
 * @returns {Object}              - Evento creado.
 */
const crearEventoViaje = async (idViaje, data, file = null) => {
    // Validar que el viaje existe
    const viajeDoc = await db.collection(COLLECTION).doc(idViaje).get();
    if (!viajeDoc.exists) {
        throw new Error('Viaje no encontrado');
    }

    const tipo = data.tipo;
    if (!tipo) {
        throw new Error('El campo "tipo" es requerido (IMU, IA, BPM).');
    }

    let eventoData;

    if (tipo === 'IA') {
        // ---- Procesamiento especial para IA ----

        // Parsear detecciones (puede venir como JSON string desde FormData)
        let detecciones;
        try {
            detecciones = typeof data.detecciones === 'string'
                ? JSON.parse(data.detecciones)
                : data.detecciones;
        } catch (e) {
            throw new Error('El campo "detecciones" debe ser un JSON válido con formato: [{ etiqueta, confianza }, ...]');
        }

        // Validar estructura
        if (!Array.isArray(detecciones) || detecciones.length === 0) {
            throw new Error('Debe incluir al menos una detección en el array "detecciones".');
        }

        for (const det of detecciones) {
            if (!det.etiqueta || det.confianza === undefined) {
                throw new Error('Cada detección debe tener "etiqueta" (string) y "confianza" (float).');
            }
        }

        // Subir imagen de evidencia a Firebase Storage
        let pathEvidencia = null;
        if (file) {
            pathEvidencia = await uploadService.subirArchivo(file, `evidencias_ia/${idViaje}`);
        }

        eventoData = {
            timestamp: data.timestamp ? new Date(data.timestamp) : new Date(),
            tipo: 'IA',
            datos: {
                detecciones: detecciones.map((det) => ({
                    etiqueta: det.etiqueta,
                    confianza: parseFloat(det.confianza),
                })),
                path_evidencia: pathEvidencia,
            },
        };
    } else {
        // ---- IMU, BPM u otros tipos ----

        // Si datos viene como string (FormData), parsearlo
        let datos;
        try {
            datos = typeof data.datos === 'string'
                ? JSON.parse(data.datos)
                : data.datos;
        } catch (e) {
            throw new Error('El campo "datos" debe ser un JSON válido.');
        }

        eventoData = {
            timestamp: data.timestamp ? new Date(data.timestamp) : new Date(),
            tipo: tipo,
            datos: datos,
        };
    }

    const docRef = await db
        .collection(COLLECTION)
        .doc(idViaje)
        .collection(SUB_COLLECTION)
        .add(eventoData);

    return { id_evento: docRef.id, id_viaje: idViaje, ...eventoData };
};

/**
 * Obtener todos los eventos de un viaje
 */
const obtenerEventosViaje = async (idViaje) => {
    const snapshot = await db
        .collection(COLLECTION)
        .doc(idViaje)
        .collection(SUB_COLLECTION)
        .orderBy('timestamp', 'asc')
        .get();

    const eventos = [];
    snapshot.forEach((doc) => {
        eventos.push({ id_evento: doc.id, ...doc.data() });
    });
    return eventos;
};

/**
 * Obtener eventos de un viaje filtrados por tipo
 */
const obtenerEventosPorTipo = async (idViaje, tipo) => {
    const snapshot = await db
        .collection(COLLECTION)
        .doc(idViaje)
        .collection(SUB_COLLECTION)
        .where('tipo', '==', tipo)
        .orderBy('timestamp', 'asc')
        .get();

    const eventos = [];
    snapshot.forEach((doc) => {
        eventos.push({ id_evento: doc.id, ...doc.data() });
    });
    return eventos;
};

/**
 * Obtener un evento específico de un viaje
 */
const obtenerEventoPorId = async (idViaje, idEvento) => {
    const doc = await db
        .collection(COLLECTION)
        .doc(idViaje)
        .collection(SUB_COLLECTION)
        .doc(idEvento)
        .get();

    if (!doc.exists) return null;
    return { id_evento: doc.id, id_viaje: idViaje, ...doc.data() };
};

/**
 * Eliminar un evento de un viaje
 */
const eliminarEventoViaje = async (idViaje, idEvento) => {
    const docRef = db
        .collection(COLLECTION)
        .doc(idViaje)
        .collection(SUB_COLLECTION)
        .doc(idEvento);

    const doc = await docRef.get();
    if (!doc.exists) return null;
    await docRef.delete();
    return { id_evento: idEvento, mensaje: 'Evento eliminado correctamente' };
};

module.exports = {
    // Viajes
    crearViaje,
    obtenerViajes,
    obtenerViajesPorConductor,
    obtenerViajesPorEmpresa,
    obtenerViajePorId,
    actualizarViaje,
    eliminarViaje,
    // Eventos de viaje
    crearEventoViaje,
    obtenerEventosViaje,
    obtenerEventosPorTipo,
    obtenerEventoPorId,
    eliminarEventoViaje,
};

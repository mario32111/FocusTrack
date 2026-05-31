const { db } = require('../fire');

const COLLECTION = 'alertas_criticas';

/**
 * Crear una nueva alerta crítica
 */
const crearAlerta = async (data) => {
    const alertaData = {
        id_viaje: data.id_viaje,
        timestamp: data.timestamp || new Date(),
        nivel_riesgo: data.nivel_riesgo, // "Bajo", "Medio", "Alto"
        tipo_alerta: data.tipo_alerta,
        descripcion: data.descripcion || null,
    };

    const docRef = await db.collection(COLLECTION).add(alertaData);
    return { id_alerta: docRef.id, ...alertaData };
};

/**
 * Obtener todas las alertas críticas
 */
const obtenerAlertas = async () => {
    const snapshot = await db.collection(COLLECTION).orderBy('timestamp', 'desc').get();
    const alertas = [];
    snapshot.forEach((doc) => {
        alertas.push({ id_alerta: doc.id, ...doc.data() });
    });
    return alertas;
};

/**
 * Obtener alertas por viaje
 */
const obtenerAlertasPorViaje = async (idViaje) => {
    const snapshot = await db
        .collection(COLLECTION)
        .where('id_viaje', '==', idViaje)
        .orderBy('timestamp', 'desc')
        .get();
    const alertas = [];
    snapshot.forEach((doc) => {
        alertas.push({ id_alerta: doc.id, ...doc.data() });
    });
    return alertas;
};

/**
 * Obtener alertas por nivel de riesgo
 */
const obtenerAlertasPorNivel = async (nivelRiesgo) => {
    const snapshot = await db
        .collection(COLLECTION)
        .where('nivel_riesgo', '==', nivelRiesgo)
        .orderBy('timestamp', 'desc')
        .get();
    const alertas = [];
    snapshot.forEach((doc) => {
        alertas.push({ id_alerta: doc.id, ...doc.data() });
    });
    return alertas;
};

/**
 * Obtener una alerta por su ID
 */
const obtenerAlertaPorId = async (id) => {
    const doc = await db.collection(COLLECTION).doc(id).get();
    if (!doc.exists) return null;
    return { id_alerta: doc.id, ...doc.data() };
};

/**
 * Actualizar una alerta
 */
const actualizarAlerta = async (id, data) => {
    const docRef = db.collection(COLLECTION).doc(id);
    const doc = await docRef.get();
    if (!doc.exists) return null;
    await docRef.update(data);
    return { id_alerta: id, ...doc.data(), ...data };
};

/**
 * Eliminar una alerta
 */
const eliminarAlerta = async (id) => {
    const docRef = db.collection(COLLECTION).doc(id);
    const doc = await docRef.get();
    if (!doc.exists) return null;
    await docRef.delete();
    return { id_alerta: id, mensaje: 'Alerta eliminada correctamente' };
};

module.exports = {
    crearAlerta,
    obtenerAlertas,
    obtenerAlertasPorViaje,
    obtenerAlertasPorNivel,
    obtenerAlertaPorId,
    actualizarAlerta,
    eliminarAlerta,
};

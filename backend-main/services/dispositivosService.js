const { db } = require('../fire');

const COLLECTION = 'dispositivos';

/**
 * Registrar un nuevo dispositivo (el ID es el ID físico del ESP32)
 */
const crearDispositivo = async (data) => {
    const dispositivoData = {
        id_usuario_asignado: data.id_usuario_asignado || null,
        ultima_conexion: data.ultima_conexion || new Date(),
    };

    // Usar el ID físico del ESP32 como Document ID
    await db.collection(COLLECTION).doc(data.id_dispositivo).set(dispositivoData);
    return { id_dispositivo: data.id_dispositivo, ...dispositivoData };
};

/**
 * Obtener todos los dispositivos
 */
const obtenerDispositivos = async () => {
    const snapshot = await db.collection(COLLECTION).get();
    const dispositivos = [];
    snapshot.forEach((doc) => {
        dispositivos.push({ id_dispositivo: doc.id, ...doc.data() });
    });
    return dispositivos;
};

/**
 * Obtener un dispositivo por su ID
 */
const obtenerDispositivoPorId = async (id) => {
    const doc = await db.collection(COLLECTION).doc(id).get();
    if (!doc.exists) return null;
    return { id_dispositivo: doc.id, ...doc.data() };
};

/**
 * Obtener dispositivo asignado a un usuario
 */
const obtenerDispositivoPorUsuario = async (idUsuario) => {
    const snapshot = await db
        .collection(COLLECTION)
        .where('id_usuario_asignado', '==', idUsuario)
        .get();

    if (snapshot.empty) return null;
    const doc = snapshot.docs[0];
    return { id_dispositivo: doc.id, ...doc.data() };
};

/**
 * Actualizar un dispositivo (ej. asignar usuario, heartbeat)
 */
const actualizarDispositivo = async (id, data) => {
    const docRef = db.collection(COLLECTION).doc(id);
    const doc = await docRef.get();
    if (!doc.exists) return null;
    await docRef.update(data);
    return { id_dispositivo: id, ...doc.data(), ...data };
};

/**
 * Actualizar heartbeat (última conexión)
 */
const actualizarHeartbeat = async (id) => {
    const docRef = db.collection(COLLECTION).doc(id);
    const doc = await docRef.get();
    if (!doc.exists) return null;
    await docRef.update({ ultima_conexion: new Date() });
    return { id_dispositivo: id, ultima_conexion: new Date() };
};

/**
 * Eliminar un dispositivo
 */
const eliminarDispositivo = async (id) => {
    const docRef = db.collection(COLLECTION).doc(id);
    const doc = await docRef.get();
    if (!doc.exists) return null;
    await docRef.delete();
    return { id_dispositivo: id, mensaje: 'Dispositivo eliminado correctamente' };
};

module.exports = {
    crearDispositivo,
    obtenerDispositivos,
    obtenerDispositivoPorId,
    obtenerDispositivoPorUsuario,
    actualizarDispositivo,
    actualizarHeartbeat,
    eliminarDispositivo,
};

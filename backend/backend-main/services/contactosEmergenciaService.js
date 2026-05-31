const { db } = require('../fire');

const COLLECTION = 'contactos_emergencia';

/**
 * Crear un nuevo contacto de emergencia
 */
const crearContacto = async (data) => {
    const docRef = await db.collection(COLLECTION).add({
        nombre: data.nombre,
        parentesco: data.parentesco,
        telefono: data.telefono,
    });
    return { id_contacto: docRef.id, ...data };
};

/**
 * Obtener todos los contactos de emergencia
 */
const obtenerContactos = async () => {
    const snapshot = await db.collection(COLLECTION).get();
    const contactos = [];
    snapshot.forEach((doc) => {
        contactos.push({ id_contacto: doc.id, ...doc.data() });
    });
    return contactos;
};

/**
 * Obtener un contacto por su ID
 */
const obtenerContactoPorId = async (id) => {
    const doc = await db.collection(COLLECTION).doc(id).get();
    if (!doc.exists) return null;
    return { id_contacto: doc.id, ...doc.data() };
};

/**
 * Actualizar un contacto de emergencia
 */
const actualizarContacto = async (id, data) => {
    const docRef = db.collection(COLLECTION).doc(id);
    const doc = await docRef.get();
    if (!doc.exists) return null;
    await docRef.update(data);
    return { id_contacto: id, ...doc.data(), ...data };
};

/**
 * Eliminar un contacto de emergencia
 */
const eliminarContacto = async (id) => {
    const docRef = db.collection(COLLECTION).doc(id);
    const doc = await docRef.get();
    if (!doc.exists) return null;
    await docRef.delete();
    return { id_contacto: id, mensaje: 'Contacto eliminado correctamente' };
};

module.exports = {
    crearContacto,
    obtenerContactos,
    obtenerContactoPorId,
    actualizarContacto,
    eliminarContacto,
};

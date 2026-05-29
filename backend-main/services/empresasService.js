const { db } = require('../fire');

const COLLECTION = 'empresas';

/**
 * Crear una nueva empresa
 */
const crearEmpresa = async (data) => {
    const docRef = await db.collection(COLLECTION).add({
        nombre_empresa: data.nombre_empresa,
        fecha_registro: new Date(),
    });
    return { id_empresa: docRef.id, ...data, fecha_registro: new Date() };
};

/**
 * Obtener todas las empresas
 */
const obtenerEmpresas = async () => {
    const snapshot = await db.collection(COLLECTION).get();
    const empresas = [];
    snapshot.forEach((doc) => {
        empresas.push({ id_empresa: doc.id, ...doc.data() });
    });
    return empresas;
};

/**
 * Obtener una empresa por su ID
 */
const obtenerEmpresaPorId = async (id) => {
    const doc = await db.collection(COLLECTION).doc(id).get();
    if (!doc.exists) return null;
    return { id_empresa: doc.id, ...doc.data() };
};

/**
 * Actualizar una empresa
 */
const actualizarEmpresa = async (id, data) => {
    const docRef = db.collection(COLLECTION).doc(id);
    const doc = await docRef.get();
    if (!doc.exists) return null;
    await docRef.update(data);
    return { id_empresa: id, ...doc.data(), ...data };
};

/**
 * Eliminar una empresa
 */
const eliminarEmpresa = async (id) => {
    const docRef = db.collection(COLLECTION).doc(id);
    const doc = await docRef.get();
    if (!doc.exists) return null;
    await docRef.delete();
    return { id_empresa: id, mensaje: 'Empresa eliminada correctamente' };
};

module.exports = {
    crearEmpresa,
    obtenerEmpresas,
    obtenerEmpresaPorId,
    actualizarEmpresa,
    eliminarEmpresa,
};

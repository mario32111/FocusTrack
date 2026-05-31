const { db } = require('../fire');

const COLLECTION = 'conductores';

/**
 * Crear un nuevo conductor (el ID es el mismo que id_usuario)
 */
const crearConductor = async (idUsuario, data) => {
    const conductorData = {
        nombre_completo: data.nombre_completo,
        num_licencia: data.num_licencia || null,
        fecha_contratacion: data.fecha_contratacion || new Date(),
        puntaje_seguridad_global: data.puntaje_seguridad_global || 100,
        estado_salud_base: data.estado_salud_base || null,
        foto_perfil_path: data.foto_perfil_path || null,
        id_dispositivo: data.id_dispositivo || null,
    };

    await db.collection(COLLECTION).doc(idUsuario).set(conductorData);
    return { id_conductor: idUsuario, ...conductorData };
};

/**
 * Obtener todos los conductores
 */
const obtenerConductores = async () => {
    const snapshot = await db.collection(COLLECTION).get();
    const conductores = [];
    snapshot.forEach((doc) => {
        conductores.push({ id_conductor: doc.id, ...doc.data() });
    });
    return conductores;
};

/**
 * Obtener un conductor por su ID
 */
const obtenerConductorPorId = async (id) => {
    const doc = await db.collection(COLLECTION).doc(id).get();
    if (!doc.exists) return null;
    return { id_conductor: doc.id, ...doc.data() };
};

/**
 * Obtener conductores por empresa (requiere join con usuarios)
 */
const obtenerConductoresPorEmpresa = async (idEmpresa) => {
    // Primero obtener los IDs de usuarios de la empresa con rol conductor
    const usuariosSnap = await db
        .collection('usuarios')
        .where('id_empresa', '==', idEmpresa)
        .where('rol', '==', 'conductor')
        .get();

    const conductores = [];
    for (const userDoc of usuariosSnap.docs) {
        const conductorDoc = await db.collection(COLLECTION).doc(userDoc.id).get();
        if (conductorDoc.exists) {
            conductores.push({ id_conductor: conductorDoc.id, ...conductorDoc.data() });
        }
    }
    return conductores;
};

/**
 * Actualizar un conductor
 */
const actualizarConductor = async (id, data) => {
    const docRef = db.collection(COLLECTION).doc(id);
    const doc = await docRef.get();
    if (!doc.exists) return null;
    await docRef.update(data);
    return { id_conductor: id, ...doc.data(), ...data };
};

/**
 * Eliminar un conductor
 */
const eliminarConductor = async (id) => {
    const docRef = db.collection(COLLECTION).doc(id);
    const doc = await docRef.get();
    if (!doc.exists) return null;
    await docRef.delete();
    return { id_conductor: id, mensaje: 'Conductor eliminado correctamente' };
};

module.exports = {
    crearConductor,
    obtenerConductores,
    obtenerConductorPorId,
    obtenerConductoresPorEmpresa,
    actualizarConductor,
    eliminarConductor,
};

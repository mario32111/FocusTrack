const { db, auth } = require('../fire');

const COLLECTION = 'usuarios';

/**
 * Crear un nuevo usuario (con Firebase Auth + Firestore)
 */
const crearUsuario = async (data) => {
    // Crear usuario en Firebase Auth
    const userRecord = await auth.createUser({
        email: data.username,
        password: data.password,
    });

    // Guardar datos adicionales en Firestore
    const userData = {
        username: data.username,
        rol: data.rol || 'conductor',
        id_empresa: data.id_empresa || null,
        id_contacto_emergencia: data.id_contacto_emergencia || null,
    };

    await db.collection(COLLECTION).doc(userRecord.uid).set(userData);

    return { id_usuario: userRecord.uid, ...userData };
};

/**
 * Obtener todos los usuarios
 */
const obtenerUsuarios = async () => {
    const snapshot = await db.collection(COLLECTION).get();
    const usuarios = [];
    snapshot.forEach((doc) => {
        usuarios.push({ id_usuario: doc.id, ...doc.data() });
    });
    return usuarios;
};

/**
 * Obtener usuarios por empresa
 */
const obtenerUsuariosPorEmpresa = async (idEmpresa) => {
    const snapshot = await db
        .collection(COLLECTION)
        .where('id_empresa', '==', idEmpresa)
        .get();
    const usuarios = [];
    snapshot.forEach((doc) => {
        usuarios.push({ id_usuario: doc.id, ...doc.data() });
    });
    return usuarios;
};

/**
 * Obtener un usuario por su ID
 */
const obtenerUsuarioPorId = async (id) => {
    const doc = await db.collection(COLLECTION).doc(id).get();
    if (!doc.exists) return null;
    return { id_usuario: doc.id, ...doc.data() };
};

/**
 * Actualizar un usuario
 */
const actualizarUsuario = async (id, data) => {
    const docRef = db.collection(COLLECTION).doc(id);
    const doc = await docRef.get();
    if (!doc.exists) return null;

    // Si se actualiza email o password, actualizar también en Auth
    const authUpdates = {};
    if (data.username) authUpdates.email = data.username;
    if (data.password) {
        authUpdates.password = data.password;
        delete data.password; // No guardar password en Firestore
    }
    if (Object.keys(authUpdates).length > 0) {
        await auth.updateUser(id, authUpdates);
    }

    await docRef.update(data);
    return { id_usuario: id, ...doc.data(), ...data };
};

/**
 * Eliminar un usuario
 */
const eliminarUsuario = async (id) => {
    const docRef = db.collection(COLLECTION).doc(id);
    const doc = await docRef.get();
    if (!doc.exists) return null;

    // Eliminar de Firebase Auth y Firestore
    await auth.deleteUser(id);
    await docRef.delete();
    return { id_usuario: id, mensaje: 'Usuario eliminado correctamente' };
};

module.exports = {
    crearUsuario,
    obtenerUsuarios,
    obtenerUsuariosPorEmpresa,
    obtenerUsuarioPorId,
    actualizarUsuario,
    eliminarUsuario,
};

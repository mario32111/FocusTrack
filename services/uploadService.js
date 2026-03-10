const path = require('path');
const { bucket } = require('../fire');

/**
 * Sube un archivo (buffer de multer) a Firebase Storage.
 * @param {Object}  file                  - Objeto file de multer (buffer, originalname, mimetype).
 * @param {string}  carpetaDestino        - Carpeta dentro del bucket (ej. "evidencias_ia").
 * @returns {Promise<string>}             - URL pública de descarga del archivo subido.
 */
const subirArchivo = async (file, carpetaDestino = 'evidencias_ia') => {
    if (!file || !file.buffer) {
        throw new Error('No se proporcionó un archivo válido para subir.');
    }

    const extension = path.extname(file.originalname);
    const nombreArchivo = `${carpetaDestino}/${Date.now()}_${Math.random().toString(36).substring(2, 8)}${extension}`;

    const blob = bucket.file(nombreArchivo);

    await blob.save(file.buffer, {
        metadata: {
            contentType: file.mimetype,
        },
    });

    // Hacer el archivo público para obtener URL directa
    await blob.makePublic();

    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${nombreArchivo}`;

    return publicUrl;
};

/**
 * Sube múltiples archivos a Firebase Storage.
 * @param {Array<Object>}  files            - Array de objetos file de multer.
 * @param {string}         carpetaDestino   - Carpeta dentro del bucket.
 * @returns {Promise<string[]>}             - Array de URLs públicas.
 */
const subirMultiplesArchivos = async (files, carpetaDestino = 'evidencias_ia') => {
    if (!files || files.length === 0) return [];
    const urls = await Promise.all(
        files.map((file) => subirArchivo(file, carpetaDestino))
    );
    return urls;
};

module.exports = {
    subirArchivo,
    subirMultiplesArchivos,
};

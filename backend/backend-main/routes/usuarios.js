const express = require('express');
const router = express.Router();
const usuariosService = require('../services/usuariosService');

// POST /usuarios - Crear usuario
router.post('/', async (req, res) => {
    try {
        const usuario = await usuariosService.crearUsuario(req.body);
        res.status(201).json(usuario);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /usuarios - Obtener todos los usuarios
router.get('/', async (req, res) => {
    try {
        const usuarios = await usuariosService.obtenerUsuarios();
        res.json(usuarios);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /usuarios/empresa/:idEmpresa - Obtener usuarios por empresa
router.get('/empresa/:idEmpresa', async (req, res) => {
    try {
        const usuarios = await usuariosService.obtenerUsuariosPorEmpresa(req.params.idEmpresa);
        res.json(usuarios);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /usuarios/:id - Obtener usuario por ID
router.get('/:id', async (req, res) => {
    try {
        const usuario = await usuariosService.obtenerUsuarioPorId(req.params.id);
        if (!usuario) return res.status(404).json({ error: 'Usuario no encontrado' });
        res.json(usuario);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// PUT /usuarios/:id - Actualizar usuario
router.put('/:id', async (req, res) => {
    try {
        const usuario = await usuariosService.actualizarUsuario(req.params.id, req.body);
        if (!usuario) return res.status(404).json({ error: 'Usuario no encontrado' });
        res.json(usuario);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// DELETE /usuarios/:id - Eliminar usuario
router.delete('/:id', async (req, res) => {
    try {
        const resultado = await usuariosService.eliminarUsuario(req.params.id);
        if (!resultado) return res.status(404).json({ error: 'Usuario no encontrado' });
        res.json(resultado);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;

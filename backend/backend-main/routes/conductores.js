const express = require('express');
const router = express.Router();
const conductoresService = require('../services/conductoresService');

// POST /conductores/:idUsuario - Crear conductor (vinculado a un usuario existente)
router.post('/:idUsuario', async (req, res) => {
    try {
        const conductor = await conductoresService.crearConductor(req.params.idUsuario, req.body);
        res.status(201).json(conductor);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /conductores - Obtener todos los conductores
router.get('/', async (req, res) => {
    try {
        const conductores = await conductoresService.obtenerConductores();
        res.json(conductores);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /conductores/empresa/:idEmpresa - Obtener conductores por empresa
router.get('/empresa/:idEmpresa', async (req, res) => {
    try {
        const conductores = await conductoresService.obtenerConductoresPorEmpresa(req.params.idEmpresa);
        res.json(conductores);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /conductores/:id - Obtener conductor por ID
router.get('/:id', async (req, res) => {
    try {
        const conductor = await conductoresService.obtenerConductorPorId(req.params.id);
        if (!conductor) return res.status(404).json({ error: 'Conductor no encontrado' });
        res.json(conductor);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// PUT /conductores/:id - Actualizar conductor
router.put('/:id', async (req, res) => {
    try {
        const conductor = await conductoresService.actualizarConductor(req.params.id, req.body);
        if (!conductor) return res.status(404).json({ error: 'Conductor no encontrado' });
        res.json(conductor);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// DELETE /conductores/:id - Eliminar conductor
router.delete('/:id', async (req, res) => {
    try {
        const resultado = await conductoresService.eliminarConductor(req.params.id);
        if (!resultado) return res.status(404).json({ error: 'Conductor no encontrado' });
        res.json(resultado);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;

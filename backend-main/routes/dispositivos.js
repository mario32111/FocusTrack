const express = require('express');
const router = express.Router();
const dispositivosService = require('../services/dispositivosService');

// POST /dispositivos - Registrar dispositivo
router.post('/', async (req, res) => {
    try {
        const dispositivo = await dispositivosService.crearDispositivo(req.body);
        res.status(201).json(dispositivo);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /dispositivos - Obtener todos los dispositivos
router.get('/', async (req, res) => {
    try {
        const dispositivos = await dispositivosService.obtenerDispositivos();
        res.json(dispositivos);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /dispositivos/usuario/:idUsuario - Obtener dispositivo por usuario
router.get('/usuario/:idUsuario', async (req, res) => {
    try {
        const dispositivo = await dispositivosService.obtenerDispositivoPorUsuario(req.params.idUsuario);
        if (!dispositivo) return res.status(404).json({ error: 'No se encontró dispositivo asignado' });
        res.json(dispositivo);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /dispositivos/:id - Obtener dispositivo por ID
router.get('/:id', async (req, res) => {
    try {
        const dispositivo = await dispositivosService.obtenerDispositivoPorId(req.params.id);
        if (!dispositivo) return res.status(404).json({ error: 'Dispositivo no encontrado' });
        res.json(dispositivo);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// PUT /dispositivos/:id - Actualizar dispositivo
router.put('/:id', async (req, res) => {
    try {
        const dispositivo = await dispositivosService.actualizarDispositivo(req.params.id, req.body);
        if (!dispositivo) return res.status(404).json({ error: 'Dispositivo no encontrado' });
        res.json(dispositivo);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// PATCH /dispositivos/:id/heartbeat - Actualizar heartbeat
router.patch('/:id/heartbeat', async (req, res) => {
    try {
        const resultado = await dispositivosService.actualizarHeartbeat(req.params.id);
        if (!resultado) return res.status(404).json({ error: 'Dispositivo no encontrado' });
        res.json(resultado);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// DELETE /dispositivos/:id - Eliminar dispositivo
router.delete('/:id', async (req, res) => {
    try {
        const resultado = await dispositivosService.eliminarDispositivo(req.params.id);
        if (!resultado) return res.status(404).json({ error: 'Dispositivo no encontrado' });
        res.json(resultado);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;

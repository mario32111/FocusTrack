const express = require('express');
const router = express.Router();
const alertasService = require('../services/alertasCriticasService');

// POST /alertas - Crear alerta crítica
router.post('/', async (req, res) => {
    try {
        const alerta = await alertasService.crearAlerta(req.body);
        res.status(201).json(alerta);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /alertas - Obtener todas las alertas
router.get('/', async (req, res) => {
    try {
        const alertas = await alertasService.obtenerAlertas();
        res.json(alertas);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /alertas/viaje/:idViaje - Obtener alertas por viaje
router.get('/viaje/:idViaje', async (req, res) => {
    try {
        const alertas = await alertasService.obtenerAlertasPorViaje(req.params.idViaje);
        res.json(alertas);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /alertas/nivel/:nivel - Obtener alertas por nivel de riesgo
router.get('/nivel/:nivel', async (req, res) => {
    try {
        const alertas = await alertasService.obtenerAlertasPorNivel(req.params.nivel);
        res.json(alertas);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /alertas/:id - Obtener alerta por ID
router.get('/:id', async (req, res) => {
    try {
        const alerta = await alertasService.obtenerAlertaPorId(req.params.id);
        if (!alerta) return res.status(404).json({ error: 'Alerta no encontrada' });
        res.json(alerta);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// PUT /alertas/:id - Actualizar alerta
router.put('/:id', async (req, res) => {
    try {
        const alerta = await alertasService.actualizarAlerta(req.params.id, req.body);
        if (!alerta) return res.status(404).json({ error: 'Alerta no encontrada' });
        res.json(alerta);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// DELETE /alertas/:id - Eliminar alerta
router.delete('/:id', async (req, res) => {
    try {
        const resultado = await alertasService.eliminarAlerta(req.params.id);
        if (!resultado) return res.status(404).json({ error: 'Alerta no encontrada' });
        res.json(resultado);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;

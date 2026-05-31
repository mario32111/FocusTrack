const express = require('express');
const multer = require('multer');
const router = express.Router();
const viajesService = require('../services/viajesService');

// Configurar multer en memoria (sin guardar en disco)
const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 10 * 1024 * 1024 }, // Máximo 10 MB
    fileFilter: (req, file, cb) => {
        if (file.mimetype.startsWith('image/')) {
            cb(null, true);
        } else {
            cb(new Error('Solo se permiten archivos de imagen.'), false);
        }
    },
});

// ========================
// VIAJES
// ========================

// POST /viajes - Crear viaje
router.post('/', async (req, res) => {
    try {
        const viaje = await viajesService.crearViaje(req.body);
        res.status(201).json(viaje);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /viajes - Obtener todos los viajes
router.get('/', async (req, res) => {
    try {
        const viajes = await viajesService.obtenerViajes();
        res.json(viajes);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /viajes/conductor/:idConductor - Obtener viajes por conductor
router.get('/conductor/:idConductor', async (req, res) => {
    try {
        const viajes = await viajesService.obtenerViajesPorConductor(req.params.idConductor);
        res.json(viajes);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /viajes/empresa/:idEmpresa - Obtener viajes por empresa
router.get('/empresa/:idEmpresa', async (req, res) => {
    try {
        const viajes = await viajesService.obtenerViajesPorEmpresa(req.params.idEmpresa);
        res.json(viajes);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /viajes/:id - Obtener viaje por ID
router.get('/:id', async (req, res) => {
    try {
        const viaje = await viajesService.obtenerViajePorId(req.params.id);
        if (!viaje) return res.status(404).json({ error: 'Viaje no encontrado' });
        res.json(viaje);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// PUT /viajes/:id - Actualizar viaje
router.put('/:id', async (req, res) => {
    try {
        const viaje = await viajesService.actualizarViaje(req.params.id, req.body);
        if (!viaje) return res.status(404).json({ error: 'Viaje no encontrado' });
        res.json(viaje);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// DELETE /viajes/:id - Eliminar viaje
router.delete('/:id', async (req, res) => {
    try {
        const resultado = await viajesService.eliminarViaje(req.params.id);
        if (!resultado) return res.status(404).json({ error: 'Viaje no encontrado' });
        res.json(resultado);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ========================
// EVENTOS DE VIAJE (Sub-colección)
// ========================

// POST /viajes/:idViaje/eventos - Crear evento en un viaje (IMU, BPM o IA)
// multer procesa FormData si se envía archivo; si no, pasa sin problema.
router.post('/:idViaje/eventos', upload.single('evidencia'), async (req, res) => {
    try {
        const evento = await viajesService.crearEventoViaje(
            req.params.idViaje,
            req.body,    // contiene "tipo" + campos según el tipo
            req.file     // archivo de imagen (solo para tipo IA, null en otros)
        );
        res.status(201).json(evento);
    } catch (error) {
        if (error.message === 'Viaje no encontrado') {
            return res.status(404).json({ error: error.message });
        }
        res.status(400).json({ error: error.message });
    }
});

// GET /viajes/:idViaje/eventos - Obtener todos los eventos de un viaje
router.get('/:idViaje/eventos', async (req, res) => {
    try {
        const eventos = await viajesService.obtenerEventosViaje(req.params.idViaje);
        res.json(eventos);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /viajes/:idViaje/eventos/tipo/:tipo - Obtener eventos filtrados por tipo
router.get('/:idViaje/eventos/tipo/:tipo', async (req, res) => {
    try {
        const eventos = await viajesService.obtenerEventosPorTipo(req.params.idViaje, req.params.tipo);
        res.json(eventos);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /viajes/:idViaje/eventos/:idEvento - Obtener evento específico
router.get('/:idViaje/eventos/:idEvento', async (req, res) => {
    try {
        const evento = await viajesService.obtenerEventoPorId(req.params.idViaje, req.params.idEvento);
        if (!evento) return res.status(404).json({ error: 'Evento no encontrado' });
        res.json(evento);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// DELETE /viajes/:idViaje/eventos/:idEvento - Eliminar evento
router.delete('/:idViaje/eventos/:idEvento', async (req, res) => {
    try {
        const resultado = await viajesService.eliminarEventoViaje(req.params.idViaje, req.params.idEvento);
        if (!resultado) return res.status(404).json({ error: 'Evento no encontrado' });
        res.json(resultado);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;

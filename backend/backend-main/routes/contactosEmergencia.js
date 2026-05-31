const express = require('express');
const router = express.Router();
const contactosService = require('../services/contactosEmergenciaService');

// POST /contactos-emergencia - Crear contacto
router.post('/', async (req, res) => {
    try {
        const contacto = await contactosService.crearContacto(req.body);
        res.status(201).json(contacto);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /contactos-emergencia - Obtener todos los contactos
router.get('/', async (req, res) => {
    try {
        const contactos = await contactosService.obtenerContactos();
        res.json(contactos);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /contactos-emergencia/:id - Obtener contacto por ID
router.get('/:id', async (req, res) => {
    try {
        const contacto = await contactosService.obtenerContactoPorId(req.params.id);
        if (!contacto) return res.status(404).json({ error: 'Contacto no encontrado' });
        res.json(contacto);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// PUT /contactos-emergencia/:id - Actualizar contacto
router.put('/:id', async (req, res) => {
    try {
        const contacto = await contactosService.actualizarContacto(req.params.id, req.body);
        if (!contacto) return res.status(404).json({ error: 'Contacto no encontrado' });
        res.json(contacto);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// DELETE /contactos-emergencia/:id - Eliminar contacto
router.delete('/:id', async (req, res) => {
    try {
        const resultado = await contactosService.eliminarContacto(req.params.id);
        if (!resultado) return res.status(404).json({ error: 'Contacto no encontrado' });
        res.json(resultado);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;

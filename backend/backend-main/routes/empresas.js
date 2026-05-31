const express = require('express');
const router = express.Router();
const empresasService = require('../services/empresasService');

// POST /empresas - Crear empresa
router.post('/', async (req, res) => {
    try {
        const empresa = await empresasService.crearEmpresa(req.body);
        res.status(201).json(empresa);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /empresas - Obtener todas las empresas
router.get('/', async (req, res) => {
    try {
        const empresas = await empresasService.obtenerEmpresas();
        res.json(empresas);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /empresas/:id - Obtener empresa por ID
router.get('/:id', async (req, res) => {
    try {
        const empresa = await empresasService.obtenerEmpresaPorId(req.params.id);
        if (!empresa) return res.status(404).json({ error: 'Empresa no encontrada' });
        res.json(empresa);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// PUT /empresas/:id - Actualizar empresa
router.put('/:id', async (req, res) => {
    try {
        const empresa = await empresasService.actualizarEmpresa(req.params.id, req.body);
        if (!empresa) return res.status(404).json({ error: 'Empresa no encontrada' });
        res.json(empresa);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// DELETE /empresas/:id - Eliminar empresa
router.delete('/:id', async (req, res) => {
    try {
        const resultado = await empresasService.eliminarEmpresa(req.params.id);
        if (!resultado) return res.status(404).json({ error: 'Empresa no encontrada' });
        res.json(resultado);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;

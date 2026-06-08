import requests
import logging

# URL base de tu backend Node.js (usando el nombre del contenedor Docker)
API_BASE_URL = "http://focustrack-backend-api:3000"

logger = logging.getLogger(__name__)

def _get(endpoint):
    """Método auxiliar para hacer peticiones GET."""
    url = f"{API_BASE_URL}{endpoint}"
    try:
        response = requests.get(url)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        logger.error(f"[API_CLIENT] Error GET {url}: {e}")
        return None

def _post(endpoint, data):
    """Método auxiliar para hacer peticiones POST."""
    url = f"{API_BASE_URL}{endpoint}"
    try:
        response = requests.post(url, json=data)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        logger.error(f"[API_CLIENT] Error POST {url}: {e}")
        return None

# --- VIAJES ---
def get_viaje(id_viaje):
    return _get(f"/viajes/{id_viaje}")

def get_viajes_conductor(id_conductor):
    return _get(f"/viajes/conductor/{id_conductor}") or []

# --- EVENTOS DEL VIAJE ---
def get_detecciones_ia(id_viaje):
    return _get(f"/viajes/{id_viaje}/eventos/tipo/IA") or []

def get_bpm(id_viaje):
    return _get(f"/viajes/{id_viaje}/eventos/tipo/BPM") or []

# --- ALERTAS CRÍTICAS ---
def get_alertas_viaje(id_viaje):
    return _get(f"/alertas/viaje/{id_viaje}") or []

# --- CONDUCTORES Y EMPRESAS ---
def get_conductor(id_conductor):
    return _get(f"/conductores/{id_conductor}")

def get_conductores_empresa(id_empresa):
    return _get(f"/conductores/empresa/{id_empresa}") or []

def get_empresa(id_empresa):
    return _get(f"/empresas/{id_empresa}")

def buscar_empresa_por_nombre(nombre: str) -> dict:
    """Busca una empresa por su nombre y devuelve su ID e información básica."""
    empresas = _get("/empresas") or []
    for emp in empresas:
        # Búsqueda insensible a mayúsculas
        if nombre.lower() in emp.get("nombre_empresa", "").lower():
            return {"id_empresa": emp.get("id_empresa"), "nombre_empresa": emp.get("nombre_empresa")}
    return {"error": f"No se encontró ninguna empresa con el nombre '{nombre}'"}

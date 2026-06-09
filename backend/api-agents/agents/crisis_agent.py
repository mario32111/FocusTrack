import os
import json
from typing import Annotated
from autogen import ConversableAgent, register_function
from api_client import (
    get_viaje, get_conductor, get_detecciones_ia,
    get_alertas_viaje, get_bpm, trigger_actuator
)

OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY", "")
config_list = [{"model": "openrouter/auto", "base_url": "https://openrouter.ai/api/v1", "api_key": OPENROUTER_API_KEY}]

# --- HERRAMIENTAS DE ACTUACIÓN ---

def activar_vibrador(id_dispositivo: Annotated[str, "ID del dispositivo IoT"], duracion_ms: Annotated[int, "Duración en ms"]) -> str:
    """Activa el vibrador del dispositivo IoT."""
    comando = {"accion": "vibrar", "parametros": {"duracion_ms": duracion_ms}}
    trigger_actuator(id_dispositivo, comando)
    return "Vibrador activado"

def activar_led(id_dispositivo: Annotated[str, "ID del dispositivo IoT"], color: Annotated[str, "Color (rojo, verde, azul)"]) -> str:
    """Cambia el color del LED RGB del dispositivo IoT."""
    comando = {"accion": "led", "parametros": {"color": color}}
    trigger_actuator(id_dispositivo, comando)
    return f"LED activado en color {color}"

def evaluate_crisis(alert_data):
    id_viaje = alert_data.get("id_viaje")
    viaje = get_viaje(id_viaje)
    
    if not viaje:
        raise ValueError(f"Viaje {id_viaje} no encontrado")
        
    driver = get_conductor(viaje.get("id_conductor")) or {}
    detections = get_detecciones_ia(id_viaje) or []
    alerts = get_alertas_viaje(id_viaje) or []
    heart_rate = get_bpm(id_viaje) or []
    
    id_dispositivo = driver.get("id_dispositivo", "ESP32_DEFAULT")

    # Procesar datos para el contexto...
    context = f"""ALERTA CRÍTICA: {alert_data.get('descripcion')}
Viaje: {id_viaje}
Conductor: {driver.get('nombre_completo', 'Desconocido')}
Dispositivo IoT: {id_dispositivo}
Riesgo: {viaje.get('score_final_viaje')}"""

    # Agentes (Evaluador, Logistica, Comunicador)
    assistant = ConversableAgent(
        name="EvaluadorCrisis",
        system_message=f"""Eres el evaluador de crisis.
Analiza la alerta y decide las acciones físicas.
Tienes acceso a las herramientas: `activar_vibrador` y `activar_led`.
Si el riesgo es alto, activa el led rojo y el vibrador inmediatamente.
Al terminar, responde TERMINAR.""",
        llm_config={"config_list": config_list, "temperature": 0.2},
        human_input_mode="NEVER",
        is_termination_msg=lambda msg: "TERMINAR" in (msg.get("content") or "").upper(),
    )

    user_proxy = ConversableAgent(
        name="UsuarioProxy",
        system_message="Ejecutas herramientas.",
        human_input_mode="NEVER",
        llm_config=False,
        is_termination_msg=lambda msg: "TERMINAR" in (msg.get("content") or "").upper(),
    )

    register_function(activar_vibrador, caller=assistant, executor=user_proxy, name="activar_vibrador", description="Activa el vibrador del dispositivo IoT")
    register_function(activar_led, caller=assistant, executor=user_proxy, name="activar_led", description="Cambia el color del LED RGB del dispositivo IoT")

    # Ejecutar crisis
    response = user_proxy.initiate_chat(assistant, message=context, max_turns=5)

    return {"status": "Acción ejecutada", "analisis": response.chat_history[-1].get("content")}

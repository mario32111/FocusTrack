import os
from autogen import ConversableAgent
from api_client import (
    get_viaje, get_conductor, get_detecciones_ia,
    get_alertas_viaje, get_bpm
)

OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY", "")
config_list = [{"model": "openrouter/auto", "base_url": "https://openrouter.ai/api/v1", "api_key": OPENROUTER_API_KEY}]

def evaluate_crisis(alert_data):
    id_viaje = alert_data.get("id_viaje")
    viaje = get_viaje(id_viaje)
    
    if not viaje:
        raise ValueError(f"Viaje {id_viaje} no encontrado")
        
    driver = get_conductor(viaje.get("id_conductor"))
    detections = get_detecciones_ia(id_viaje)
    alerts = get_alertas_viaje(id_viaje)
    heart_rate = get_bpm(id_viaje)

    # Procesar detecciones
    all_detections = []
    for ev in detections:
        datos = ev.get("datos", {})
        det_list = datos.get("detecciones", [])
        for d in det_list:
            all_detections.append(d.get('etiqueta'))

    # Procesar BPM
    bpm_values = []
    for ev in heart_rate[-5:]:  # últimos 5
        bpm = ev.get("datos", {}).get("pulsaciones")
        if bpm:
            bpm_values.append(bpm)

    context = f"""ALERTA CRÍTICA RECIBIDA:
Tipo: {alert_data.get('tipo_alerta')}
Nivel: {alert_data.get('nivel_riesgo')}
Descripción: {alert_data.get('descripcion')}

CONDUCTOR:
Nombre: {driver.get('nombre_completo') if driver else 'Desconocido'}
Contacto emergencia: {driver.get('contacto_emergencia') if driver else 'No registrado'}

VIAJE:
Duración: {viaje.get('hora_inicio')} - {viaje.get('hora_fin')}
Riesgo actual: {viaje.get('score_final_viaje')}

DETECCIONES RECIENTES: {all_detections[-5:] if all_detections else 'Ninguna'}
HISTORIAL ALERTAS: {len(alerts)} alertas en este viaje
BPM RECIENTE: {bpm_values}"""

    evaluator = ConversableAgent(
        name="EvaluadorSeguridad",
        llm_config={"config_list": config_list, "temperature": 0.2},
        system_message="Evalúa la severidad de la alerta basada en el contexto. Responde con: CRITICO, ALTO, MEDIO o BAJO. Justifica en 1 oración.",
        human_input_mode="NEVER",
    )

    logistics = ConversableAgent(
        name="Logistica",
        llm_config={"config_list": config_list, "temperature": 0.3},
        system_message="Evalúa opciones de acción: detenerse, continuar, desviar. Recomienda la más segura.",
        human_input_mode="NEVER",
    )

    communicator = ConversableAgent(
        name="Comunicador",
        llm_config={"config_list": config_list, "temperature": 0.5},
        system_message="Genera mensaje de notificación para el contacto de emergencia y administrador. Sé claro y conciso.",
        human_input_mode="NEVER",
    )

    eval_response = evaluator.initiate_chat(evaluator, message=context, max_turns=1)
    eval_result = eval_response.chat_history[-1].get("content") if eval_response.chat_history else "Error"

    log_response = logistics.initiate_chat(logistics, message=f"Evaluación: {eval_result}", max_turns=1)
    log_result = log_response.chat_history[-1].get("content") if log_response.chat_history else "Error"

    comm_response = communicator.initiate_chat(communicator, message=f"Evaluación: {eval_result}\nAcción: {log_result}", max_turns=1)
    comm_result = comm_response.chat_history[-1].get("content") if comm_response.chat_history else "Error"

    return {
        "id_alerta": alert_data.get("id_alerta"),
        "risk_level": eval_result.split()[0] if eval_result else "DESCONOCIDO",
        "evaluator_analysis": eval_result,
        "logistics_assessment": log_result,
        "notification_message": comm_result,
        "driver_name": driver.get("nombre_completo") if driver else "Desconocido",
        "emergency_contact": driver.get("contacto_emergencia") if driver else None
    }

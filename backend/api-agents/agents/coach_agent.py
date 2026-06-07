import os
from datetime import datetime
from autogen import ConversableAgent
from api_client import (
    get_viaje, get_detecciones_ia, get_alertas_viaje,
    get_bpm, get_conductor
)

OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY", "")
config_list = [{"model": "openrouter/auto", "base_url": "https://openrouter.ai/api/v1", "api_key": OPENROUTER_API_KEY}]

def generate_coach_feedback(id_viaje):
    viaje = get_viaje(id_viaje)
    if not viaje:
        raise ValueError(f"Viaje {id_viaje} no encontrado")

    detections = get_detecciones_ia(id_viaje)
    alerts = get_alertas_viaje(id_viaje)
    heart_rate = get_bpm(id_viaje)
    
    driver = None
    if viaje.get("id_conductor"):
        driver = get_conductor(viaje.get("id_conductor"))

    # Extraer detecciones de la estructura anidada de eventos IA
    all_detections = []
    for ev in detections:
        datos = ev.get("datos", {})
        det_list = datos.get("detecciones", [])
        for d in det_list:
            all_detections.append(f"{d.get('etiqueta')} ({d.get('confianza', 0):.2f})")
    
    detection_summary = ", ".join(all_detections) or "Ninguna detección"
    alert_summary = ", ".join([f"{a.get('tipo_alerta')} - nivel {a.get('nivel_riesgo')}" for a in alerts]) or "Ninguna alerta"
    
    # Extraer BPM
    bpm_values = []
    for ev in heart_rate:
        datos = ev.get("datos", {})
        bpm = datos.get("pulsaciones")
        if bpm:
            bpm_values.append(bpm)
            
    bpm_summary = f"Promedio: {sum(bpm_values)//len(bpm_values)} BPM" if bpm_values else "Sin datos"

    driver_name = driver.get("nombre_completo", "Conductor Desconocido") if driver else "Conductor Desconocido"

    user_prompt = f"""Viaje: {driver_name} - {viaje.get('fecha')}
Puntaje de riesgo final: {viaje.get('score_final_viaje', 'No calculado')}
Detecciones IA: {detection_summary}
Alertas: {alert_summary}
Ritmo cardíaco: {bpm_summary}"""

    coach = ConversableAgent(
        name="CoachSeguridad",
        llm_config={"config_list": config_list, "temperature": 0.7},
        system_message="""Eres un coach de seguridad vial para conductores profesionales.
Genera feedback constructivo y personalizado en español.
Estructura tu respuesta así:
1. RESUMEN: 2-3 oraciones sobre el viaje
2. MEJORAS: Lista de áreas a mejorar
3. SUGERENCIONES: Consejos concretos para el próximo viaje
4. PUNTUAJE: Número del 0 al 100 (0=perfecto, 100=peligroso)""",
        human_input_mode="NEVER",
    )

    response = coach.initiate_chat(coach, message=user_prompt, max_turns=1)
    
    feedback_text = response.chat_history[-1].get("content") if response.chat_history else "Error generando feedback"

    feedback = {
        "id_viaje": id_viaje,
        "feedback_text": feedback_text,
        "risk_score": viaje.get("score_final_viaje", 0),
        "created_at": datetime.utcnow().isoformat()
    }

    return feedback

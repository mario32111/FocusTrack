import os
import json
from typing import Annotated
from autogen import ConversableAgent, register_function
from api_client import (
    buscar_empresa_por_nombre, get_conductores_empresa, get_viajes_conductor
)

OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY", "")
config_list = [{"model": "openrouter/auto", "base_url": "https://openrouter.ai/api/v1", "api_key": OPENROUTER_API_KEY}]

# --- HERRAMIENTAS PARA EL AGENTE ---

def obtener_conductores_con_riesgo(id_empresa: Annotated[str, "El ID de la empresa (NO el nombre)"]) -> str:
    """Obtiene la lista de conductores de una empresa y calcula su riesgo promedio basado en viajes."""
    drivers = get_conductores_empresa(id_empresa)
    if not drivers:
        return "No hay conductores registrados para esta empresa."
    
    driver_info = []
    for d in drivers[:10]: # Limitamos a 10 para no saturar
        viajes = get_viajes_conductor(d.get("id_conductor", d.get("id")))
        viajes_con_score = [v for v in viajes if v.get("score_final_viaje") is not None]
        
        riesgo_promedio = 0
        if viajes_con_score:
            riesgo_promedio = sum(v.get("score_final_viaje", 0) for v in viajes_con_score) / len(viajes_con_score)
            
        driver_info.append({
            "nombre": d.get("nombre_completo"),
            "riesgo_promedio": round(riesgo_promedio, 2),
            "viajes_analizados": len(viajes_con_score)
        })
        
    return json.dumps(driver_info)


def chat_with_fleet(question: str):
    # Asistente LLM que decide qué herramientas usar
    assistant = ConversableAgent(
        name="AnalistaFlota",
        system_message="""Eres un analista de flotas de transporte. Tu trabajo es responder a las consultas del usuario sobre empresas y conductores.
        
TIENES HERRAMIENTAS DISPONIBLES:
1. Siempre busca primero el ID de la empresa usando `buscar_empresa_por_nombre` pasándole el nombre que te dio el usuario.
2. Una vez tengas el ID, usa `obtener_conductores_con_riesgo` pasándole el ID exacto.
3. Al recibir los datos, formula tu respuesta final en español y responde con la palabra TERMINAR en tu mensaje final para cerrar la conversación.

Si no encuentras datos, infórmalo amablemente.""",
        llm_config={"config_list": config_list, "temperature": 0.1},
        human_input_mode="NEVER",
        is_termination_msg=lambda msg: "TERMINAR" in (msg.get("content") or "").upper(),
    )

    # Proxy del usuario que ejecuta las funciones localmente
    user_proxy = ConversableAgent(
        name="EjecutorDeHerramientas",
        system_message="Solo ejecutas funciones y devuelves el resultado. No conversas.",
        is_termination_msg=lambda msg: "TERMINAR" in (msg.get("content") or "").upper(),
        human_input_mode="NEVER",
        llm_config=False # No usa LLM, solo ejecuta código
    )

    # Registrar las funciones en AutoGen 0.2.x (versión que tienes instalada)
    register_function(
        buscar_empresa_por_nombre,
        caller=assistant,
        executor=user_proxy,
        name="buscar_empresa_por_nombre",
        description="Busca una empresa por nombre (ej. 'Translogistica') y devuelve su ID."
    )
    
    register_function(
        obtener_conductores_con_riesgo,
        caller=assistant,
        executor=user_proxy,
        name="obtener_conductores_con_riesgo",
        description="Recibe el ID de una empresa y devuelve la lista de conductores y su nivel de riesgo."
    )

    # Iniciar la conversación
    response = user_proxy.initiate_chat(assistant, message=question, max_turns=5)

    # Extraer la última respuesta real del asistente antes del cierre
    final_answer = "No se pudo generar respuesta"
    for msg in reversed(response.chat_history):
        content = msg.get("content", "")
        if msg.get("role") == "user" and content and not content.startswith("{") and "TERMINAR" not in content.upper():
            # AutoGen guarda los mensajes del Assistant como role='user' en el chat_history del UserProxy
            # Ignoramos los que son outputs de funciones (que empiezan con { o [)
            final_answer = content
            break
            
    # Si la respuesta contenía la palabra terminar, se la quitamos
    final_answer = final_answer.replace("TERMINAR", "").replace("terminar", "").strip()

    if not final_answer or final_answer == "No se pudo generar respuesta":
         # Fallback si el parsing anterior falla
         for msg in reversed(response.chat_history):
             if msg.get("name") == "AnalistaFlota" and msg.get("content"):
                 final_answer = msg.get("content").replace("TERMINAR", "").strip()
                 break

    return {
        "answer": final_answer,
        "company": "Analizada automáticamente", # Como el agente la busca, no la pasamos estática
        "drivers_analyzed": "Variable"
    }

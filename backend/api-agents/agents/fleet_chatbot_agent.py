import os
from autogen import ConversableAgent
from api_client import (
    get_conductores_empresa, get_viajes_conductor, get_empresa
)

OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY", "")
config_list = [{"model": "openrouter/auto", "base_url": "https://openrouter.ai/api/v1", "api_key": OPENROUTER_API_KEY}]

def chat_with_fleet(question, id_empresa):
    company = get_empresa(id_empresa)
    if not company:
        raise ValueError(f"Empresa {id_empresa} no encontrada")
        
    drivers = get_conductores_empresa(id_empresa)

    driver_info = []
    for d in drivers[:10]:
        viajes = get_viajes_conductor(d.get("id_conductor", d.get("id")))
        driver_info.append({
            "nombre": d.get("nombre_completo"),
            "id": d.get("id_conductor", d.get("id")),
            "riesgo_promedio": sum(v.get("score_final_viaje", 0) for v in viajes if v.get("score_final_viaje") is not None) / max(len([v for v in viajes if v.get("score_final_viaje") is not None]), 1)
        })

    context = f"Empresa: {company.get('nombre_empresa', 'Desconocida')}\nConductores y Riesgo Promedio: {driver_info}"

    assistant = ConversableAgent(
        name="AnalistaFlota",
        llm_config={"config_list": config_list, "temperature": 0.3},
        system_message=f"""Eres un analista de flotas de transporte. Responde preguntas sobre la empresa y sus conductores.
Contexto de la empresa:\n{context}
Responde en español de forma clara y concisa. Si necesitas datos específicos de un conductor, indícalo.""",
        human_input_mode="NEVER",
    )

    response = assistant.initiate_chat(assistant, message=question, max_turns=1)

    return {
        "answer": response.chat_history[-1].get("content") if response.chat_history else "No se pudo generar respuesta",
        "company": company.get("nombre_empresa"),
        "drivers_analyzed": len(drivers)
    }

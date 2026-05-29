import os
import random
from autogen import ConversableAgent
from dotenv import load_dotenv

load_dotenv()

# --- CONFIGURACIÓN PARA MODELOS CLOUD (OPENROUTER) ---
# Se utiliza OpenRouter para acceder a modelos de alto rendimiento de forma rápida.
# Asegúrate de configurar tu API Key antes de ejecutar el script.
# Puedes obtener una en: https://openrouter.ai/keys

OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY", "")

config_list_cloud = [
    {
        "model": "openrouter/auto", # OpenRouter se encarga de rutear al mejor modelo disponible
        "base_url": "https://openrouter.ai/api/v1",
        "api_key": OPENROUTER_API_KEY,
    }
]

def main():
    # Elegimos el número en Python y se lo pasamos al System Prompt del Host
    secret_number = random.randint(1, 100)
    print(f"\n[SISTEMA] El número secreto elegido es: {secret_number}\n")

    # --- AGENTE HOST ---
    # Conoce el número secreto y debe dar pistas.
    host = ConversableAgent(
        name="Host",
        llm_config={"config_list": config_list_cloud, "temperature": 0.1},
        system_message=f"""Eres el anfitrión de un juego de adivinar un número.
El número secreto es {secret_number}. 
El usuario (Guesser) intentará adivinarlo.
Tu ÚNICA tarea es comparar el número que dice el Guesser con el número secreto {secret_number}.

Reglas estrictas para responder:
- Si el número del Guesser es menor a {secret_number}, responde ÚNICAMENTE: "Más alto".
- Si el número del Guesser es mayor a {secret_number}, responde ÚNICAMENTE: "Más bajo".
- Si el número del Guesser es exactamente {secret_number}, responde ÚNICAMENTE: "TERMINAR".

NO des pistas adicionales. NO converses. NO uses signos de puntuación extra. Solo "Más alto", "Más bajo" o "TERMINAR".
""",
        human_input_mode="NEVER",
        is_termination_msg=lambda msg: "TERMINAR" in msg.get("content", "").upper(),
    )

    # --- AGENTE GUESSER ---
    # Intenta adivinar basándose en las pistas.
    guesser = ConversableAgent(
        name="Guesser",
        llm_config={"config_list": config_list_cloud, "temperature": 0.7},
        system_message="""Eres un jugador jugando a adivinar un número secreto entre 1 y 100.
En cada turno debes decir un único número. 
El Host te dirá "Más alto" o "Más bajo".
Usa la estrategia de búsqueda binaria para adivinar lo más rápido posible.

Reglas estrictas para responder:
- Responde ÚNICAMENTE con el número que estás adivinando. Por ejemplo: "50" o "75".
- NO incluyas texto extra, explicaciones ni preguntas. Solo el número.
""",
        human_input_mode="NEVER",
    )

    print("--- INICIANDO EL JUEGO ---")
    
    # El Guesser inicia la conversación tirando el primer número
    guesser.initiate_chat(
        host,
        message="50",
        max_turns=15 # Límite de seguridad para que no se quede en un loop infinito
    )

if __name__ == "__main__":
    main()

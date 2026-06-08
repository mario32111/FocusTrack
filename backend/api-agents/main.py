from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from api_client import get_viaje, get_viajes_conductor, get_conductor
from agents.coach_agent import generate_coach_feedback
from agents.fleet_chatbot_agent import chat_with_fleet
from agents.crisis_agent import evaluate_crisis
from mqtt_client import start_mqtt_background

app = FastAPI(title="API Agents (AutoGen)")

@app.on_event("startup")
async def startup():
    start_mqtt_background(callback=lambda data: print(f"[ALERTA MQTT] {data}"))

@app.get("/")
def read_root():
    return {"message": "Hola desde api-agents. Sistema multi-agente listo."}

@app.get("/health")
def health():
    return {"status": "ok", "agents": ["coach", "chatbot", "crisis"]}

class CoachRequest(BaseModel):
    id_viaje: str

@app.post("/agent/coach")
def agent_coach(req: CoachRequest):
    try:
        feedback = generate_coach_feedback(req.id_viaje)
        return feedback
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

class ChatRequest(BaseModel):
    question: str

@app.post("/agent/chat")
def agent_chat(req: ChatRequest):
    try:
        response = chat_with_fleet(req.question)
        return response
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

class CrisisRequest(BaseModel):
    id_alerta: str
    id_viaje: str
    tipo_alerta: str
    nivel_riesgo: str
    descripcion: str

@app.post("/agent/crisis")
def agent_crisis(req: CrisisRequest):
    try:
        result = evaluate_crisis(req.dict())
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/agent/history/{id_conductor}")
def agent_history(id_conductor: str):
    try:
        viajes = get_viajes_conductor(id_conductor)
        return {"id_conductor": id_conductor, "viajes": viajes}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

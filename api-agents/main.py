from fastapi import FastAPI

app = FastAPI(title="API Agents (AutoGen)")

@app.get("/")
def read_root():
    return {"message": "Hola desde api-agents. Sistema multi-agente listo."}

from fastapi import FastAPI

app = FastAPI(title="API Detection")

@app.get("/")
def read_root():
    return {"message": "hola desde api-detection"}

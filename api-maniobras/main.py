from fastapi import FastAPI

app = FastAPI(title="API Maniobras")

@app.get("/")
def read_root():
    return {"message": "hola desde api-maniobras"}

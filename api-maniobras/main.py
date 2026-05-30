import os
import numpy as np
import joblib
import pandas as pd
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="API Maniobras")

MODEL_PATH = os.path.join(os.path.dirname(__file__), "modelo_conduccion_97.pkl")
modelo = joblib.load(MODEL_PATH)

CLASS_NAMES = {
    1: "Conducción normal",
    2: "Frenado brusco",
    3: "Aceleración brusca",
    4: "Giro brusco",
}

class SensorReading(BaseModel):
    GyroX: float
    GyroY: float
    GyroZ: float
    AccX: float
    AccY: float
    AccZ: float

class SensorBatch(BaseModel):
    readings: list[SensorReading]

def feature_engineering(readings: list[dict]) -> pd.DataFrame:
    df = pd.DataFrame(readings)
    df["Acc_Mag"] = np.sqrt(df["AccX"] ** 2 + df["AccY"] ** 2 + df["AccZ"] ** 2)
    sensores = ["GyroX", "GyroY", "GyroZ", "AccX", "AccY", "AccZ", "Acc_Mag"]
    for s in sensores:
        df[f"{s}_mean"] = df[s].rolling(window=min(10, len(df)), min_periods=1).mean()
        df[f"{s}_std"] = df[s].rolling(window=min(10, len(df)), min_periods=1).std().fillna(0)
    return df

@app.get("/")
def read_root():
    return {"message": "API de Clasificación de Maniobras - Modelo RandomForest 97% accuracy"}

@app.get("/health")
def health():
    return {"status": "ok", "model_loaded": modelo is not None}

@app.post("/predict")
def predict(batch: SensorBatch):
    if len(batch.readings) < 1:
        return {"error": "Se necesitan al menos 1 lectura de sensores"}

    readings = [r.model_dump() for r in batch.readings]
    df_features = feature_engineering(readings)
    feature_cols = [
        "GyroX", "GyroY", "GyroZ", "AccX", "AccY", "AccZ", "Acc_Mag",
        "GyroX_mean", "GyroX_std", "GyroY_mean", "GyroY_std",
        "GyroZ_mean", "GyroZ_std", "AccX_mean", "AccX_std",
        "AccY_mean", "AccY_std", "AccZ_mean", "AccZ_std",
        "Acc_Mag_mean", "Acc_Mag_std",
    ]
    X = df_features[feature_cols].values
    predicciones = modelo.predict(X)
    probabilidades = modelo.predict_proba(X)
    resultados = []
    for i, (pred, proba) in enumerate(zip(predicciones, probabilidades)):
        resultados.append({
            "indice": i,
            "clase": int(pred),
            "maniobra": CLASS_NAMES.get(int(pred), "Desconocida"),
            "confianza": round(float(max(proba)) * 100, 2),
        })
    return {
        "total": len(resultados),
        "resultados": resultados,
    }

@app.post("/predict-latest")
def predict_latest(batch: SensorBatch):
    if len(batch.readings) < 1:
        return {"error": "Se necesitan al menos 1 lectura de sensores"}

    readings = [r.model_dump() for r in batch.readings]
    df_features = feature_engineering(readings)
    feature_cols = [
        "GyroX", "GyroY", "GyroZ", "AccX", "AccY", "AccZ", "Acc_Mag",
        "GyroX_mean", "GyroX_std", "GyroY_mean", "GyroY_std",
        "GyroZ_mean", "GyroZ_std", "AccX_mean", "AccX_std",
        "AccY_mean", "AccY_std", "AccZ_mean", "AccZ_std",
        "Acc_Mag_mean", "Acc_Mag_std",
    ]
    X = df_features[feature_cols].values
    pred = modelo.predict(X[-1:])
    proba = modelo.predict_proba(X[-1:])
    clase = int(pred[0])
    return {
        "clase": clase,
        "maniobra": CLASS_NAMES.get(clase, "Desconocida"),
        "confianza": round(float(max(proba[0])) * 100, 2),
        "todas_las_probabilidades": {
            CLASS_NAMES.get(i + 1, f"Clase {i + 1}"): round(float(p) * 100, 2)
            for i, p in enumerate(proba[0])
        },
    }

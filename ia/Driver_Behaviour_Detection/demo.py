import cv2
from ultralytics import YOLO

# Carga el modelo (best2.pt es el que terminó con mejores métricas en Colab)
model = YOLO('driver_behaviour_v1.pt')

# Prueba con 1 o 0 según tu cámara
cap = cv2.VideoCapture(0)

# Optimizaciones de hardware (opcional si tienes GPU NVIDIA en Windows)
# model.to('cuda') 

print("Iniciando monitoreo... Ajusta tu posición. Presiona 'q' para salir.")

while cap.isOpened():
    success, frame = cap.read()
    if not success:
        break

    # --- CORRECCIÓN 1: Formato de Color ---
    # YOLO espera RGB, OpenCV da BGR. 
    frame = cv2.flip(frame, 1)
    img_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

    # --- CORRECCIÓN 2: Inferencia ---
    # Usamos imgsz=640 porque así se entrenó en PTA 2
    results = model.predict(
        source=img_rgb, 
        conf=0.15,      # Umbral bajo para ver TODO lo que detecta
        imgsz=640, 
        verbose=False
    )

    # Procesamos los resultados (aquí ya no necesitamos el bucle for de stream)
    annotated_frame = results[0].plot()

    # --- CORRECCIÓN 3: Regresar a BGR para mostrar con imshow ---
    # plot() devuelve RGB, cv2.imshow necesita BGR
    final_frame = cv2.cvtColor(annotated_frame, cv2.COLOR_RGB2BGR)

    cv2.imshow("FocusTrack AI - Test Real", final_frame)

    if cv2.waitKey(1) & 0xFF == ord("q"):
        break

cap.release()
cv2.destroyAllWindows()
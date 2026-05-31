import os
import yaml
from collections import Counter

# 1. Ruta a la carpeta de tu dataset (ajústala a tu ruta real)
dataset_path = 'dataset/train' # O 'dataset/val'
yaml_path = 'dataset/data.yaml'

# 2. Cargar los nombres de las clases desde el data.yaml
with open(yaml_path, 'r') as f:
    data = yaml.safe_load(f)
    class_names = data['names']

# 3. Contar las etiquetas
label_dir = os.path.join(dataset_path, 'labels')
counts = Counter()

for label_file in os.listdir(label_dir):
    if label_file.endswith('.txt'):
        with open(os.path.join(label_dir, label_file), 'r') as f:
            for line in f:
                class_id = int(line.split()[0])
                counts[class_id] += 1

# 4. Mostrar resultados
print(f"{'ID':<5} | {'Clase':<20} | {'Instancias'}")
print("-" * 40)
for class_id, count in sorted(counts.items()):
    name = class_names[class_id] if class_id < len(class_names) else "Desconocida"
    print(f"{class_id:<5} | {name:<20} | {count}")
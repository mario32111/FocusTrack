# Driver Behaviour Detection

### Introduction

Driver behavior detection is a critical application in intelligent transportation systems aimed at enhancing road safety and minimizing accidents caused by risky driving practices.

Using newest YOLO version - YOLOv11, a state-of-the-art object detection model, this approach leverages real-time capabilities to identify and classify driver behaviors such as distraction, drowsiness, eating, smoking, and seatbelt.

### Prepare Dataset

I used the dataset on Roboflow, if you would like to use your custom dataset, you can skip this instruction.

Before downloading the dataset, you should login into <a href="https://universe.roboflow.com/">Roboflow</a> to get an api key.

Replace your-api-key by your own api key at <a href="./utils/download_dataset.py">download_dataset.py</a>.

Run the python file to download the dataset:

```bash
python ./utils/download_dataset.py
```

### Visualize Data

I also provided the <a href="./utils/visualize.py">visualize.py</a> in utils to get randomly some samples to demonstrate the annotation.

Configure your path to images and labels folders then run the python file to show examples:

```
python ./utils/visualize.py
```

<img src="./imgs/vis.jpg"/>

### Training

Since the training script is strictly followed by Ultralytics instructions, visit <a href="https://docs.ultralytics.com/models/yolo11/">here</a> to read more.

### Performance

<img src="./imgs/confusion_matrix.png"/>
<table>
  <tr>
    <td><img src="./imgs/P_curve.png" alt="P Curve"/></td>
    <td><img src="./imgs/R_curve.png" alt="R Curve"/></td>
  </tr>
</table>
<table>
  <tr>
    <td><img src="./imgs/F1_curve.png" alt="F1 Curve"/></td>
    <td><img src="./imgs/PR_curve.png" alt="PR Curve"/></td>
  </tr>
</table>
<table>
  <tr>
    <td><img src="./imgs/val_batch1_pred.jpg" alt="Batch 1 Prediction"/></td>
    <td><img src="./imgs/val_batch2_pred.jpg" alt="Batch 2 Prediction"/></td>
  </tr>
</table>

### Demo

After completed training, you can deploy the best model as a web-based via <a href="https://anvil.works/">Anvil</a> platform.

Since Anvil's architecture is client-server, you should configure both side.

Client-side:

- Create a blank workspace in Anvil
- Upload the UI code in <a href="./demo/Driver Anomal Behaviour Detection.yaml">Driver Anomal Behaviour Detection.yaml</a> into the Anvil web.

Server-side:

- Create an up-link to connect your app to existing code. The up-link code should be:

```
server_XXXXX...
```

- Open <a href="./demo/demo.ipynb">demo.ipynb</a> notebook and paste your up-link code in:

```
anvil.server.connect("server_XXXXX...")
```

- Ensure the path to weights of your model.
- Press "Run All" to start the session.

from roboflow import Roboflow
rf = Roboflow(api_key="yxf6ArlOA5Yxvo5uE1Ty")
project = rf.workspace("driver-miviz").project("pta-s7fnu-nzeqr")
version = project.version(2)
dataset = version.download("yolov11")
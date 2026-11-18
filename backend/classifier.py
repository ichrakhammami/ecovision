import os
from threading import Lock

MODEL = os.getenv("ECOVISION_MODEL")
LABELS = ("Plastique", "Papier / carton", "Verre", "Métal", "Organique")
_lock = Lock()
_interpreter = None


def classify(image):
    global _interpreter
    if not MODEL:
        return None
    import numpy as np
    from ai_edge_litert.interpreter import Interpreter

    with _lock:
        if _interpreter is None:
            interpreter = Interpreter(model_path=MODEL)
            interpreter.allocate_tensors()
            _interpreter = interpreter
        input_info = _interpreter.get_input_details()[0]
        output_info = _interpreter.get_output_details()[0]
        _, height, width, channels = input_info["shape"]
        if channels != 3 or input_info["dtype"] != np.float32 or output_info["dtype"] != np.float32:
            raise RuntimeError("Le modèle doit accepter RGB float32 et produire des probabilités float32.")
        data = np.asarray(image.resize((width, height)), dtype=np.float32) / 255.0
        _interpreter.set_tensor(input_info["index"], data[None, ...])
        _interpreter.invoke()
        scores = _interpreter.get_tensor(output_info["index"]).reshape(-1)
        if scores.size != len(LABELS):
            raise RuntimeError("Le modèle doit produire exactement cinq probabilités.")
        index = int(scores.argmax())
        return (LABELS[index], float(scores[index])) if scores[index] >= 0.65 else None

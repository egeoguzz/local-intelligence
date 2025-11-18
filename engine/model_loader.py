import mlx.core as mx
from mlx_lm import load

class ModelLoader:
    """
    Loads the Phi-3 4-bit MLX model from local storage.
    """
    def __init__(self, model_path="models/phi3-mlx-4bit"):
        self.model_path = model_path
        self.model, self.tokenizer = None, None

    def load(self):
        print(f"[ModelLoader] Loading model from {self.model_path} ...")
        self.model, self.tokenizer = load(self.model_path)
        print("[ModelLoader] Model loaded successfully.")
        return self.model, self.tokenizer

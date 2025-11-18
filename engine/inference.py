import time
from mlx_lm import stream_generate
from engine.model_loader import ModelLoader

class InferenceEngine:
    def __init__(self):
        print("[InferenceEngine] Initializing...")
        loader = ModelLoader()
        self.model, self.tokenizer = loader.load()
        print("[InferenceEngine] Ready.")

    def run(self, prompt: str, max_tokens: int = 256):
        print("[Local Intelligence] Starting generation...")
        start = time.time()

        output_text = ""

        # MLX 0.28.x — NO temperature, NO top_p, NO top_k
        for chunk in stream_generate(
            model=self.model,
            tokenizer=self.tokenizer,
            prompt=prompt,
            max_tokens=max_tokens,
        ):
            output_text += chunk.text or ""

        duration = round(time.time() - start, 2)
        print(f"[Local Intelligence] Done in {duration}s")

        return output_text.strip()

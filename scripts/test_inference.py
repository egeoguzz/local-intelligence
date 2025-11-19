from engine.inference import InferenceEngine

engine = InferenceEngine()

prompt = "Explain the core idea of Local Intelligence in one paragraph."
output = engine.run(prompt)

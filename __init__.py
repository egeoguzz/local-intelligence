from engine.model_loader import ModelLoader
from engine.inference import InferenceEngine

def main():
    print("=== Local Intelligence – Interactive Console ===")
    loader = ModelLoader()
    model, tokenizer = loader.load()

    engine = InferenceEngine(model, tokenizer)

    while True:
        user = input("\nYou: ")
        if user.lower() in ["exit", "quit"]:
            break
        engine.run(user)

if __name__ == "__main__":
    main()

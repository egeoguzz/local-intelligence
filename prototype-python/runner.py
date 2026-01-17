#!/usr/bin/env python3
import argparse

from engine.inference import InferenceEngine


def main():
    parser = argparse.ArgumentParser(
        description="Local Intelligence - on-device MLX LLM CLI"
    )
    parser.add_argument(
        "-p", "--prompt",
        type=str,
        help="Single prompt to send to the Local Intelligence engine."
    )
    parser.add_argument(
        "--max-tokens",
        type=int,
        default=256,
        help="Maximum number of tokens to generate (default: 256)."
    )

    args = parser.parse_args()

    engine = InferenceEngine()

    # If a single prompt is provided -> one-shot mode
    if args.prompt:
        output = engine.run(args.prompt, max_tokens=args.max_tokens)
        print("\n=== Local Intelligence Response ===\n")
        print(output)
        return

    # Otherwise -> interactive chat mode
    print("Local Intelligence CLI")
    print("Type 'exit' or 'quit' to leave.\n")

    while True:
        try:
            user_input = input("You: ")
        except (KeyboardInterrupt, EOFError):
            print("\nExiting.")
            break

        if user_input.strip().lower() in ("exit", "quit"):
            print("Goodbye.")
            break

        output = engine.run(user_input, max_tokens=args.max_tokens)
        print("\nLocal Intelligence:", output, "\n")


if __name__ == "__main__":
    main()

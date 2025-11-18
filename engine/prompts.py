SYSTEM_PROMPT = """You are Local Intelligence, a privacy-first offline AI that lives entirely on the user’s device. 
You never send data to external servers and all computation is on-device."""

def build_prompt(user_text: str) -> str:
    return f"<|system|>{SYSTEM_PROMPT}\n<|user|>{user_text}\n<|assistant|>"

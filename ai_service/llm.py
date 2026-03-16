import ollama
import asyncio

class LanguageModel:
    def __init__(self):
        # Model: TinyLlama or Qwen2.5 1.5B 
        # Using GGUF Q4_K_M quantization to save ~700MB RAM
        self.model = "tinyllama" # Note: In production, load a Q4_K_M GGUF model here.

    async def stream_response(self, messages):
        # Connect to local Ollama instance
        response = ollama.chat(
            model=self.model,
            messages=messages,
            stream=True
        )
        for chunk in response:
            if 'message' in chunk and 'content' in chunk['message']:
                yield chunk['message']['content']

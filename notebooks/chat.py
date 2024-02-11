import transformers
import torch

CHAT_HISTORY = []

DEFAULT_SYSTEM_PROMPT = "You are a friendly, helpful chatbot assistant."

class Chatbot:
    """
    Interface with an LLM created using HuggingFace text generation pipeline.
    """
    
    def __init__(self, pipe: transformers.pipelines.text_generation.TextGenerationPipeline):
        self.pipe = pipe
        
    def start_new_chat(self, system_prompt: str = "You are a friendly, helpful chatbot assistant."):
        self.messages = [{
                "role": "system",
                "content": system_prompt
        }]

    def send_user_chat_message(self, user_message: str) -> str:
        self.messages.append({
            "role": "user",
            "content": user_message
        })
        pipe_input = self.pipe.tokenizer.apply_chat_template(
            self.messages,
            tokenize=False,
            add_generation_prompt=True
        )
        output = self.pipe(pipe_input, max_new_tokens=256, do_sample=True, temperature=0.7, top_k=50, top_p=0.95, return_full_text=False)
        resp = output[0]["generated_text"]
        self.messages.append({
            "role": "assistant",
            "content": resp
        })
        print(resp)

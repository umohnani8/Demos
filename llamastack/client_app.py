import os
from llama_stack_client import LlamaStackClient
from llama_stack_client.types import UserMessage # Keep this for user messages

# --- Configuration (rest remains the same) ---
LLAMA_STACK_SERVER_URL = os.getenv("LLAMA_STACK_SERVER_URL", "http://0.0.0.0:8321")
MODEL_ID = os.getenv("LLAMA_STACK_MODEL_ID", "bartowski/Meta-Llama-3-8B-Instruct-GGUF/Meta-Llama-3-8B-Instruct-Q5_K_M.gguf")

# --- Initialize the client (rest remains the same) ---
try:
    client = LlamaStackClient(base_url=LLAMA_STACK_SERVER_URL)
    print(f"Connecting to LlamaStack server at: {LLAMA_STACK_SERVER_URL}")
except Exception as e:
    print(f"Error initializing LlamaStackClient: {e}")
    print("Please ensure your LlamaStack server is running and accessible at the specified URL.")
    exit()

# --- Simple Chat Completion ---
def chat_with_llamastack(prompt: str):
    # Combine system instruction with the user's first prompt
    # The model should still understand this as an instruction
    # Add context about current date and location for better answers
    system_instruction = (
        "You are a helpful AI assistant. "
        "The current date is Tuesday, June 10, 2025. "
        "The current location is Boston, Massachusetts, United States."
    )
    full_prompt = f"{system_instruction}\n\nUser: {prompt}"

    messages = [
        # Pass the combined instruction and user prompt as a single UserMessage
        UserMessage(content=full_prompt, role="user"),
    ]

    print(f"\nUser: {prompt}")
    print("Thinking...")

    try:
        response = client.inference.chat_completion(
            messages=messages,
            model_id=MODEL_ID,
            stream=False, # Set to True for streaming responses
        )

        if response and response.completion_message:
            print(f"Assistant: {response.completion_message.content}")
        else:
            print("Assistant: No valid response received.")

    except Exception as e:
        print(f"Error during chat completion: {e}")
        print("Please check your LlamaStack server logs for more details.")
        print("Ensure the model ID specified is correct and available on the server.")

# --- Run the application (rest remains the same) ---
if __name__ == "__main__":
    print("--- LlamaStack Chat Application ---")
    print(f"Using model: {MODEL_ID}")
    print("Type 'quit', 'exit', or 'bye' to end the conversation.")

    while True:
        user_input = input("\nEnter your message: ")
        if user_input.lower() in ["quit", "exit", "bye"]:
            print("Exiting chat. Goodbye!")
            break
        chat_with_llamastack(user_input)

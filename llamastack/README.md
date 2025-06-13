# Running Llama Stack with Containers!

## :memo: Llama Stack with Ramalama

### Step 1: Prerequisites

Install the following:

- Podman
- Python 3.10+
- pip
- Ramalama

Verify versions and installation with:
```
podman --version
python3 --version
pip --version
ramalama version
```

### Step 2: Pull Down your LLM

Pull down the model that we will use for our AI application. For this example, we will pull down the **bartowski/Meta-Llama-3-8B-Instruct-GGUF/Meta-Llama-3-8B-Instruct-Q5_K_M.gguf** model from Huggingface.

```
ramalama pull huggingface://bartowski/Meta-Llama-3-8B-Instruct-GGUF/Meta-Llama-3-8B-Instruct-Q5_K_M.gguf
```

This is the llama3 8 billion parameters model.

### Step 3: Serve the Model using Ramalama

Serve the model using Ramalama so that Llamastack has a model endpoint to use for your application.

```
ramalama serve --name ramalama huggingface://bartowski/Meta-Llama-3-8B-Instruct-GGUF/Meta-Llama-3-8B-Instruct-Q5_K_M.gguf
```

This will serve the model at **http://http://0.0.0.0:8080/** that you can access in your browser.

Ramalama creates a container using podman under the hood to serve your model.
```
podman ps

CONTAINER ID  IMAGE                          COMMAND               CREATED        STATUS        PORTS                   NAMES
043a84a0208e  quay.io/ramalama/ramalama:0.8  /usr/libexec/rama...  5 seconds ago  Up 5 seconds  0.0.0.0:8080->8080/tcp  ramalama
```


### Step 3: Setup Environment Variables

Set up the **INFERENCE_MODEL** environment variable to point to the name of your model. For this example it is:
```
export INFERENCE_MODEL=llama3.2:3b-instruct-fp16
```

Set up the **LLAMA_STACK_PORT** environment variable to point to the llamastack port, which is 8321 by default:
```
export LLAMA_STACK_PORT=8321
```

### Step 4: Run Llama Stack Server with Podman

Pull the llamastack image.
```
podman pull docker.io/llamastack/distribution-ollama
```

Create a local directory to mount into the container's filesystem.
```
mkdir -p ~/.llama
```

Run the server using podman.
```
podman run --network=host -it \
  -p $LLAMA_STACK_PORT:$LLAMA_STACK_PORT \
  -v ~/.llama:/root/.llama \
  --env INFERENCE_MODEL=$INFERENCE_MODEL \
  --env OLLAMA_URL=http://127.0.0.1:11434 \
  llamastack/distribution-ollama \
  --port $LLAMA_STACK_PORT
```

### Step 5: Run an AI Application

Let's run an AI application to use the the model and llama stack servers that we started!

There is a llama stack streamlit UI application that gives you the ability to explore all that llama stack has to offer.

```
podman run -it --name ramalamastack-ui \
  -p 8501:8501 \
  -e LLAMA_STACK_ENDPOINT=http://host.containers.internal:8321\
  quay.io/redhat-et/streamlit_client:0.1.0
```

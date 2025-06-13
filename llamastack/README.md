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

> Note: There is a bug with how the ports are exposed on Macs using podman machine, so to make this work with  a Mac, you will have to run the following command instead to serve the mode. This exposes the ports correctly.
```
podman run -d --rm \
    -p 8080:8080 \
    -p 8501:8501 \
    -p 8321:8321 \
    --label ai.ramalama \
    --label ai.ramalama.model=huggingface://bartowski/Meta-Llama-3-8B-Instruct-GGUF/Meta-Llama-3-8B-Instruct-Q5_K_M.gguf \
    --label ai.ramalama.engine=podman \
    --label ai.ramalama.runtime=llama.cpp \
    --label ai.ramalama.port=8080 \
    --label ai.ramalama.command=serve \
    --security-opt=label=disable \
    #--device /dev/dri \ <- UNCOMMENT IF USING GPUs!!
    --cap-drop=all --security-opt=no-new-privileges \
    --pull newer -t -i \
    --name ramalama \
    --env=HOME=/tmp \
    --init \
    --mount=type=bind,src=/Users/somalley/.local/share/ramalama/store/huggingface/bartowski/Meta-Llama-3-8B-Instruct-GGUF/Meta-Llama-3-8B-Instruct-Q5_K_M.gguf/blobs/sha256-16d824ee771e0e33b762bb3dc3232b972ac8dce4d2d449128fca5081962a1a9e,destination=/mnt/models/model.file,ro \
    quay.io/ramalama/ramalama:0.9 /usr/libexec/ramalama/ramalama-serve-core llama-server --port 8080 --model /mnt/models/model.file --jinja --alias bartowski/Meta-Llama-3-8B-Instruct-GGUF/Meta-Llama-3-8B-Instruct-Q5_K_M.gguf --ctx-size 2048 --temp 0.8 --cache-reuse 256 -ngl 999 --threads 6 --host 0.0.0.0
```

### Step 4: Setup Environment Variables

Set up the **INFERENCE_MODEL** environment variable to point to the name of your model.
```
export INFERENCE_MODEL=bartowski/Meta-Llama-3-8B-Instruct-GGUF/Meta-Llama-3-8B-Instruct-Q5_K_M.gguf
```

(Optional) Set up **TAVILY_SEARCH_API_KEY** environment variable to enable websearch within LlamaStack.
Tavily is the default in the LlamaStack UI shown below. See [tavily.com](https://www.tavily.com/) to obtain a free trial API Key.
```
export TAVILY_SEARCH_API_KEY=replaceme
```

### Step 5: Run Llama Stack Server with Podman

Use podman to run the llama-stack image built for Ramalama.
```
podman run \
 --net=host \
 --env RAMALAMA_URL=http://0.0.0.0:8080 \
 --env INFERENCE_MODEL=$INFERENCE_MODEL \
 quay.io/ramalama/llama-stack
```

Add the following parameter above to add websearch function.
```
--env TAVILY_SEARCH_API_KEY=$TAVILY_SEARCH_API_KEY \
```

Set the environment **RAMALAMA_URL** to point to the endpoint that the model is served on.

This will start the Llama Stack API server on the endpoint **http://0.0.0.0:8321**. You can view the docs for the llama stack server in your browser at **http://0.0.0.0:8321/docs**.

### Step 6: Run an AI Application

#### Local Application

Let's run an AI application to use the model and llama stack servers that we started!

Let's create simple python script starting a chatbot to talk with the model. The script can be found [here](https://github.com/umohnani8/Demos/blob/master/llamastack/client_app.py).

```
python client_app.py
```

This will start a chatbot in your terminal that you can interact with. Go ahead and ask it some questions!

#### Containerized Application

We can also run an application inside a container and connect it to the llama stack server running inside a podman contaier.

Llama Stack provides a streamlit-ui that we can run in a container to interact with everything it has to offer.

```
podman run -it --rm \
  --name ramalamastack-ui \
  -p 8501:8501 \
  -e LLAMA_STACK_ENDPOINT=http://host.containers.internal:8321 \
  quay.io/redhat-et/streamlit_client:0.1.0
```

This will expose the streamlit-ui application on **http://http://0.0.0.0:8501**.
The **LLAMA_STACK_ENDPOINT** environment variable is used to tell  podman to connect to the 8321 port on your host's network as the llama stack server is running inside another container with the port exposed to your host.

There you go, you have served your model, started the llama stack server, and started your AI applications in containers!

## Podify the Containers!

Instead of starting 3 different containers everytime, let's put these containers together in a pod. This can be easily done with the `podman kube generate` command.

Grab the container IDs of the containers we started above.
```
podman ps

CONTAINER ID  IMAGE                                     COMMAND               CREATED        STATUS        PORTS                             NAMES
d06ed4e0271b  quay.io/ramalama/ramalama:0.8             /usr/libexec/rama...  9 minutes ago  Up 9 minutes  0.0.0.0:8080->8080/tcp            ramalama
4310162e0a5b  localhost/ramalama-llamastack:latest      /bin/sh -c llama ...  8 minutes ago  Up 8 minutes                                    llamastack
fed4a88eb19f  quay.io/redhat-et/streamlit_client:0.1.0                        3 seconds ago  Up 4 seconds  0.0.0.0:8501->8501/tcp, 8080/tcp  ramalamastack-ui
```

Generate the Kubernetes YAML file.
```
podman kube generate d06ed4e0271b 4310162e0a5b fed4a88eb19f -f ramalama-llamastack-ui.yaml
```

This will create a file that will look something like [this](https://github.com/umohnani8/Demos/blob/master/llamastack/ramalama-llamastack-ui.yaml).

> Note: You will need to edit the generated yaml to add the [following](https://github.com/umohnani8/Demos/blob/master/llamastack/ramalama-llamastack-ui.yaml#L83-L85) to the llamastack container definition so that the ports are exposed correctly.

Let's stop and remove all the containers we started.
```
podman rm -af
```

Now, let's play the Kube yaml we just generated.
```
podman kube play ramalama-llamastack-ui.yaml
```

Wait a few seconds for all the containers to come up. Once they are up, you will be able to access the streamlit-ui on **http://http://0.0.0.0:8501** as we did earlier.

> Note: You can also generate a yaml with only the model and llamastack containers, it will look something like [this](https://github.com/umohnani8/Demos/blob/master/llamastack/ramalama-llamastack.yaml). This way, you can run your AI application in a separate container and connect it the llama stack endpoint exposed by this pod.

Have fun playing with containers and Llama Stack!

## Resources

- [Ramalama](https://github.com/containers/ramalama)
- [Ramalama-stack](https://github.com/containers/ramalama-stack)
- [Llama Stack](https://github.com/meta-llama/llama-stack)

#!/usr/bin/env bash
set -euo pipefail

MODEL="hf://bartowski/Meta-Llama-3-8B-Instruct-GGUF/Meta-Llama-3-8B-Instruct-Q5_K_M.gguf"
CAR_IMAGE="localhost/llama3-car:latest"
GOOSE_WEB_IMAGE="quay.io/acui/goose:latest"
POD_NAME="goose-llama3"
KUBE_YAML="goose-llama3-deployment.yaml"
KUBE_YAML_FIXED="goose-llama3-deployment-fixed.yaml"
MODEL_PATH=$(find ~/.local/share/ramalama/store/huggingface/bartowski/Meta-Llama-3-8B-Instruct-GGUF -name "Meta-Llama-3-8B-Instruct-Q5_K_M.gguf" -type f | grep snapshots | head -1)


log() {
  echo
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

check_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: $1 not installed"
    exit 1
  }
}

demo() {
  echo -e "$ \033[32m$*\033[0m"
  read -r -p ""
  "$@"
}

log "Checking dependencies"

check_cmd ramalama
check_cmd podman
check_cmd minikube
check_cmd kubectl

echo "All required commands found."

log "Step 1: Pull Llama-3-8B model with ramalama"
demo ramalama pull "$MODEL"

log "Step 2: Get the podman command that ramalama serve would use"
echo "Running: ramalama --dryrun serve -p 8080 $MODEL"
SERVE_CMD=$(ramalama --dryrun serve -p 8080 "$MODEL")
echo
echo "RamaLama would run this podman command:"
echo "$SERVE_CMD"
read -r -p ""

log "Step 3: Create Podman pod with ports 8080 (API) and 7681 (Web UI)"
# Clean up existing pod if present
podman pod rm -f "$POD_NAME" 2>/dev/null || true
demo podman pod create --name "$POD_NAME" -p 8080:8080 -p 7681:7681

# log "Step 4: Find the Llama-3 model file path"
# echo "Searching for model file..."
# MODEL_PATH=$(find ~/.local/share/ramalama/store/huggingface/bartowski/Meta-Llama-3-8B-Instruct-GGUF -name "Meta-Llama-3-8B-Instruct-Q5_K_M.gguf" -type f | grep snapshots | head -1)
# echo "Found model at: $MODEL_PATH"
# read -r -p ""

log "Step 4: Start Llama-3 server in the pod"
demo podman run -d --pod "$POD_NAME" --name llama3-server \
  --security-opt=label=disable --cap-drop=all --security-opt=no-new-privileges \
  --device /dev/dri --env=HOME=/tmp --init \
  -v "$MODEL_PATH:/mnt/models/model.file:ro" \
  quay.io/ramalama/ramalama:latest \
  llama-server --host 0.0.0.0 --port 8080 --model /mnt/models/model.file \
  --jinja --no-warmup --alias llama3 --temp 0.8 --cache-reuse 256 -ngl 999 --threads 6

echo
echo "Waiting for llama3 server to start..."
sleep 5

log "Step 5: Show the Goose providers.yaml configuration"
echo "Goose configuration uses this providers.yaml:"
echo
demo cat goose-config/providers.yaml
echo
read -r -p ""

log "Step 6: Start Goose web interface in the pod"
demo podman run -d --pod "$POD_NAME" --name goose-web "$GOOSE_WEB_IMAGE"

echo
echo "Pod is running with both containers:"
demo podman ps --pod

echo
echo "Access points:"
echo "  - Goose Web UI: http://localhost:7681"
echo "  - Llama-3 API:  http://localhost:8080"
read -r -p ""

log "Step 7: Convert Llama-3 model to OCI car-type image for Kubernetes"
demo ramalama convert --type=car "$MODEL" "$CAR_IMAGE"

echo
echo "Car-type image created:"
demo podman images | grep llama3-car || true

log "Step 8: Generate Kubernetes YAML from the running pod"
demo podman generate kube --service --type=deployment "$POD_NAME" -f "$KUBE_YAML"

echo
echo "Generated YAML saved to: $KUBE_YAML"
echo "Manual edits required:"
echo "  1. Add initContainer to copy model from car-type image"
echo "  2. Add volumeMounts to llama3-server container"
echo "  3. Replace hostPath volumes with emptyDir"
echo "  4. Add imagePullPolicy: Never for local images"
read -r -p ""

echo
echo "Delete podman pod to clean up"
demo podman pod rm -f "$POD_NAME"

log "Step 9: Check Minikube status"
demo minikube status

log "Step 10: Load images into Minikube"
echo "Loading llama3-car image..."
demo bash -c "podman save $CAR_IMAGE | minikube image load -"

echo
echo "Loading goose-web image..."
demo bash -c "podman save $GOOSE_WEB_IMAGE | minikube image load -"

echo
echo "Verify images loaded:"
demo minikube image ls | grep -E "llama3-car|goose-web" || true

log "Step 11: Apply the Kubernetes YAML to Minikube"
demo kubectl apply -f "$KUBE_YAML_FIXED"

echo
echo "Waiting for pod to be ready..."
demo kubectl wait --for=condition=ready pod -l app=goose-llama3 --timeout=180s

log "Step 12: Get the service URLs"
demo kubectl get svc goose-llama3

echo
echo "Getting Minikube service URLs:"
demo minikube service goose-llama3 --url

echo
echo "Delete Kubernetes deployment to clean up"
demo kubectl delete -f "$KUBE_YAML_FIXED"

log "Step 13: Run with Podman Quadlet"
echo "Setting up Quadlet directory..."
QUADLET_DIR="$HOME/.config/containers/systemd"
demo mkdir -p "$QUADLET_DIR"

echo
echo "Creating Quadlet unit file..."
demo bash -c "cat > $QUADLET_DIR/goose-llama3.kube <<EOF
[Unit]
Description=Goose + Llama-3-8B Pod
After=network-online.target

[Kube]
Yaml=$PWD/$KUBE_YAML_FIXED
PublishPort=7681:7681
PublishPort=8080:8080

[Service]
Restart=on-failure

[Install]
WantedBy=default.target
EOF"

echo
echo "Reloading systemd user daemon..."
demo systemctl --user daemon-reload

echo
echo "Starting goose-llama3 with Quadlet..."
demo systemctl --user start goose-llama3.service

echo
echo "Checking service status..."
demo systemctl --user status goose-llama3.service --no-pager

echo
echo "Listing running containers..."
demo podman ps

echo
echo "Viewing service logs..."
demo journalctl --user -u goose-llama3.service -n 20 --no-pager

echo
echo "Access points:"
echo "  - Goose Web UI: http://localhost:7681"
echo "  - Llama-3 API:  http://localhost:8080"
read -r -p ""

echo
echo "Stopping and cleaning up Quadlet service..."
demo systemctl --user stop goose-llama3.service

echo
echo "Removing Quadlet configuration..."
demo rm -f "$QUADLET_DIR/goose-llama3.kube"

echo
echo "Reloading systemd user daemon..."
demo systemctl --user daemon-reload

echo
echo "============================================================"
echo "Demo complete!"
echo "============================================================"


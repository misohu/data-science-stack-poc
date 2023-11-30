#!/bin/bash
sudo snap install yq
sudo snap install juju-wait --classic
sudo snap install juju --classic --channel=3.1/stable
sudo snap install microk8s --classic --channel=1.26/stable

sudo usermod -a -G microk8s ubuntu
sudo mkdir /home/ubuntu/.kube
sudo mkdir -p /home/ubuntu/.local/share
sudo chown -f -R ubuntu /home/ubuntu/.kube
sudo chown -f -R ubuntu /home/ubuntu/.local/share

sudo microk8s enable dns storage metallb:"10.64.140.43-10.64.140.49,192.168.0.105-192.168.0.111"
sleep 30
sudo microk8s.kubectl wait --for=condition=available -nkube-system deployment/coredns deployment/hostpath-provisioner
sudo microk8s.kubectl -n kube-system rollout status ds/calico-node

sudo microk8s config | juju add-k8s my-k8s --client
juju bootstrap my-k8s uk8s-controller
juju add-model kubeflow

# Deploy charms
juju deploy ./bundle.yaml --trust

juju wait-for application mlflow-server --query='name=="mlflow-server" && (status=="active" || status=="idle")' --timeout=15m0s
juju wait-for application mlflow-minio --query='name=="mlflow-minio" && (status=="active" || status=="idle")' --timeout=15m0s
juju wait-for application jupyter-controller --query='name=="jupyter-controller" && (status=="active" || status=="idle")' --timeout=15m0s

juju_output=$(juju run mlflow-server/0 get-minio-credentials)

namespace="user-namespace"
pvc_name="notebook-workplace-data"
notebook_name="user-notebook"

# Extract access-key and secret-access-key using awk
access_key=$(echo "$juju_output" | awk '/access-key:/ {print $2; exit}')
secret_access_key=$(echo "$juju_output" | awk '/secret-access-key:/ {print $2; exit}')

sudo microk8s kubectl create namespace $namespace
sudo microk8s kubectl label namespaces $namespace app.kubernetes.io/part-of=kubeflow-profile --overwrite=true

sed -e "s|{{ namespace }}|$namespace|g" \
    -e "s|{{ pvc-name }}|$pvc_name|g" \
    -e "s|{{ notebook-name }}|$notebook_name|g" \
    -e "s|{{ aws_access_key_id }}|$access_key|g" \
    -e "s|{{ aws_secret_access_key }}|$secret_access_key|g" \
    manifests/manifests.yaml > manifests/manifests-generated.yaml

sudo microk8s kubectl apply -f manifests/manifests-generated.yaml


# Function to wait for the pod to be ready
wait_for_pod() {
    # Loop until the pod is ready
    while true; do
        # Use kubectl to get the pod status in the specified namespace
        pod_status=$(sudo microk8s kubectl get po -n "$namespace" "$notebook_name-0" -o jsonpath='{.status.phase}')
                                                                                

        # Check if the pod is in the "Running" state
        if [ "$pod_status" == "Running" ]; then
            echo "Pod is ready!"
            break
        else
            echo "Pod is not ready. Current status: $pod_status"
            sleep 5  # Adjust the sleep duration as needed
        fi
    done
}

# Function to get the ClusterIP of the service with the same name as the pod
get_service_cluster_ip() {
    service_name="$notebook_name"

    # Use kubectl to get the ClusterIP of the service in the specified namespace
    cluster_ip=$(sudo microk8s kubectl get svc -n "$namespace" "$service_name" -o jsonpath='{.spec.clusterIP}')

    echo "Access the notebook at http://$cluster_ip/notebook/$namespace/$notebook_name/"
}

get_mlflow_cluster_ip() {
    service_name="mlflow-server"

    # List Kubernetes services
    mlflow_cluster_ip=$(sudo microk8s kubectl get svc -n "kubeflow" "$service_name" -o jsonpath='{.spec.clusterIP}')

    if [ -z "$mlflow_cluster_ip" ]; then
        echo "Service 'mlflow-server' not found."
    else
        echo "Access MLflow ui at: http://$mlflow_cluster_ip:5000"
    fi
}

# Wait for the pod to be ready
wait_for_pod

# Get the ClusterIP of the service with the same name as the pod
get_service_cluster_ip

# Get MLflow clusterIP
get_mlflow_cluster_ip

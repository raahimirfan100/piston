# Piston GCP Deployment Guide

This directory contains Kubernetes manifests and scripts to deploy Piston on Google Cloud Platform (GKE).

## Prerequisites

- `gcloud` CLI installed and authenticated
- GCP project with billing enabled
- Sufficient quota for GKE cluster and Filestore

## Architecture

- **GKE Standard Cluster**: Allows privileged containers required for cgroup v2 isolation
- **Filestore**: Shared persistent storage for `/piston/packages` across replicas
- **LoadBalancer Service**: Exposes Piston API on port 2000
- **ConfigMap**: Environment variables for Piston configuration

## Deployment Steps

See `deploy.sh` for automated deployment or follow manual steps below.

### 1. Set Environment Variables

```bash
export PROJECT_ID="your-project-id"
export REGION="us-central1"
export ZONE="us-central1-a"
export CLUSTER_NAME="piston-cluster"
export FILESTORE_NAME="piston-packages"
```

### 2. Create Project and Enable APIs

```bash
# Create project (if new)
gcloud projects create $PROJECT_ID --name="Piston Code Execution"

# Set as active project
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable file.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable monitoring.googleapis.com
```

### 3. Create Filestore Instance

```bash
gcloud filestore instances create $FILESTORE_NAME \
    --zone=$ZONE \
    --tier=BASIC_HDD \
    --file-share=name="packages",capacity=1TB \
    --network=name="default"
```

### 4. Create GKE Cluster

```bash
gcloud container clusters create $CLUSTER_NAME \
    --zone=$ZONE \
    --machine-type=n2-standard-4 \
    --num-nodes=2 \
    --enable-autoscaling \
    --min-nodes=1 \
    --max-nodes=5 \
    --enable-autorepair \
    --enable-autoupgrade \
    --enable-ip-alias \
    --workload-pool=$PROJECT_ID.svc.id.goog \
    --addons=GcpFilestoreCsiDriver
```

### 5. Get Cluster Credentials

```bash
gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE
```

### 6. Deploy Piston

```bash
# Update PV manifest with Filestore IP
FILESTORE_IP=$(gcloud filestore instances describe $FILESTORE_NAME --zone=$ZONE --format="value(networks[0].ipAddresses[0])")
sed -i "s/FILESTORE_IP_PLACEHOLDER/$FILESTORE_IP/g" pv.yaml

# Apply manifests
kubectl apply -f namespace.yaml
kubectl apply -f pv.yaml
kubectl apply -f pvc.yaml
kubectl apply -f configmap.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

### 7. Wait for LoadBalancer IP

```bash
kubectl get service -n piston -w
```

### 8. Install Language Packages

```bash
# Get API endpoint
PISTON_URL=$(kubectl get service piston-api -n piston -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Install packages using CLI
cd ../cli
npm install
node index.js -u http://$PISTON_URL:2000 ppman install python node
```

## Configuration

Edit `configmap.yaml` to adjust Piston configuration:

- `PISTON_MAX_CONCURRENT_JOBS`: Max concurrent executions (default: 64)
- `PISTON_COMPILE_TIMEOUT`: Compile timeout in ms (default: 10000)
- `PISTON_RUN_TIMEOUT`: Run timeout in ms (default: 3000)
- `PISTON_MAX_PROCESS_COUNT`: Max processes per job (default: 64)
- `PISTON_DISABLE_NETWORKING`: Disable network in jobs (default: true)

## Monitoring

View logs:
```bash
kubectl logs -n piston -l app=piston-api -f
```

Check pod status:
```bash
kubectl get pods -n piston
```

## Scaling

Manually scale replicas:
```bash
kubectl scale deployment piston-api -n piston --replicas=3
```

Enable Horizontal Pod Autoscaler:
```bash
kubectl autoscale deployment piston-api -n piston --cpu-percent=70 --min=2 --max=10
```

## Security Considerations

- Privileged containers are required for isolate/cgroup v2
- Consider dedicated node pool with taints
- Implement network policies for egress control
- Use Cloud Armor for rate limiting on LoadBalancer

## Cleanup

```bash
kubectl delete namespace piston
gcloud container clusters delete $CLUSTER_NAME --zone=$ZONE
gcloud filestore instances delete $FILESTORE_NAME --zone=$ZONE
```

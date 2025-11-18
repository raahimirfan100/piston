#!/usr/bin/env bash

# Piston GCP Deployment Script
# This script automates the deployment of Piston on Google Cloud Platform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration - Set these before running
PROJECT_ID="${PROJECT_ID:-}"
REGION="${REGION:-us-central1}"
ZONE="${ZONE:-us-central1-a}"
CLUSTER_NAME="${CLUSTER_NAME:-piston-cluster}"
FILESTORE_NAME="${FILESTORE_NAME:-piston-packages}"
FILESTORE_TIER="${FILESTORE_TIER:-BASIC_HDD}"
FILESTORE_SIZE="${FILESTORE_SIZE:-1TB}"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI not found. Please install it first."
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install it first."
        exit 1
    fi
    
    if [ -z "$PROJECT_ID" ]; then
        log_error "PROJECT_ID not set. Please set it before running."
        echo "Usage: PROJECT_ID=your-project-id $0"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

set_project() {
    log_info "Setting active project to $PROJECT_ID..."
    gcloud config set project "$PROJECT_ID"
    
    # Verify project exists
    if ! gcloud projects describe "$PROJECT_ID" &> /dev/null; then
        log_warn "Project $PROJECT_ID does not exist or you don't have access."
        read -p "Would you like to create it? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Creating project $PROJECT_ID..."
            gcloud projects create "$PROJECT_ID" --name="Piston Code Execution"
        else
            log_error "Cannot proceed without a valid project"
            exit 1
        fi
    fi
}

enable_apis() {
    log_info "Enabling required GCP APIs..."
    gcloud services enable container.googleapis.com \
        compute.googleapis.com \
        file.googleapis.com \
        artifactregistry.googleapis.com \
        logging.googleapis.com \
        monitoring.googleapis.com \
        --project="$PROJECT_ID"
    log_info "APIs enabled successfully"
}

create_filestore() {
    log_info "Checking if Filestore instance exists..."
    
    if gcloud filestore instances describe "$FILESTORE_NAME" --zone="$ZONE" --project="$PROJECT_ID" &> /dev/null; then
        log_warn "Filestore instance $FILESTORE_NAME already exists, skipping creation"
        return 0
    fi
    
    log_info "Creating Filestore instance for package storage..."
    log_info "This may take 5-10 minutes..."
    
    gcloud filestore instances create "$FILESTORE_NAME" \
        --zone="$ZONE" \
        --tier="$FILESTORE_TIER" \
        --file-share=name="packages",capacity="$FILESTORE_SIZE" \
        --network=name="default" \
        --project="$PROJECT_ID"
    
    log_info "Filestore instance created successfully"
}

create_gke_cluster() {
    log_info "Checking if GKE cluster exists..."
    
    if gcloud container clusters describe "$CLUSTER_NAME" --zone="$ZONE" --project="$PROJECT_ID" &> /dev/null; then
        log_warn "GKE cluster $CLUSTER_NAME already exists, skipping creation"
        return 0
    fi
    
    log_info "Creating GKE Standard cluster..."
    log_info "This may take 5-10 minutes..."
    
    gcloud container clusters create "$CLUSTER_NAME" \
        --zone="$ZONE" \
        --machine-type=n2-standard-4 \
        --num-nodes=2 \
        --enable-autoscaling \
        --min-nodes=1 \
        --max-nodes=5 \
        --enable-autorepair \
        --enable-autoupgrade \
        --enable-ip-alias \
        --workload-pool="$PROJECT_ID.svc.id.goog" \
        --addons=GcpFilestoreCsiDriver \
        --project="$PROJECT_ID"
    
    log_info "GKE cluster created successfully"
}

get_cluster_credentials() {
    log_info "Getting cluster credentials..."
    gcloud container clusters get-credentials "$CLUSTER_NAME" \
        --zone="$ZONE" \
        --project="$PROJECT_ID"
    log_info "Credentials configured for kubectl"
}

update_filestore_ip() {
    log_info "Getting Filestore IP address..."
    
    FILESTORE_IP=$(gcloud filestore instances describe "$FILESTORE_NAME" \
        --zone="$ZONE" \
        --project="$PROJECT_ID" \
        --format="value(networks[0].ipAddresses[0])")
    
    if [ -z "$FILESTORE_IP" ]; then
        log_error "Failed to get Filestore IP address"
        exit 1
    fi
    
    log_info "Filestore IP: $FILESTORE_IP"
    log_info "Updating PersistentVolume manifest..."
    
    # Create a temporary file with updated IP
    sed "s/FILESTORE_IP_PLACEHOLDER/$FILESTORE_IP/g" pv.yaml > pv-updated.yaml
    mv pv-updated.yaml pv.yaml
    
    log_info "PersistentVolume manifest updated"
}

deploy_piston() {
    log_info "Deploying Piston to Kubernetes..."
    
    # Apply manifests in order
    kubectl apply -f namespace.yaml
    kubectl apply -f pv.yaml
    kubectl apply -f pvc.yaml
    kubectl apply -f configmap.yaml
    kubectl apply -f deployment.yaml
    kubectl apply -f service.yaml
    
    log_info "Kubernetes resources created"
}

wait_for_pods() {
    log_info "Waiting for Piston pods to be ready..."
    kubectl wait --for=condition=ready pod \
        -l app=piston-api \
        -n piston \
        --timeout=300s
    log_info "Pods are ready"
}

wait_for_loadbalancer() {
    log_info "Waiting for LoadBalancer IP assignment..."
    log_info "This may take a few minutes..."
    
    for i in {1..60}; do
        EXTERNAL_IP=$(kubectl get service piston-api -n piston -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        
        if [ -n "$EXTERNAL_IP" ]; then
            log_info "LoadBalancer IP assigned: $EXTERNAL_IP"
            echo "$EXTERNAL_IP" > piston-api-ip.txt
            return 0
        fi
        
        echo -n "."
        sleep 5
    done
    
    log_error "Timeout waiting for LoadBalancer IP"
    exit 1
}

display_summary() {
    log_info "=========================================="
    log_info "Deployment Complete!"
    log_info "=========================================="
    echo ""
    
    EXTERNAL_IP=$(cat piston-api-ip.txt 2>/dev/null || echo "Not available")
    
    log_info "Piston API URL: http://$EXTERNAL_IP:2000"
    log_info "Runtimes endpoint: http://$EXTERNAL_IP:2000/api/v2/runtimes"
    log_info "Execute endpoint: http://$EXTERNAL_IP:2000/api/v2/execute"
    echo ""
    
    log_info "Next steps:"
    echo "1. Install language packages using the CLI:"
    echo "   cd ../cli && npm install"
    echo "   node index.js -u http://$EXTERNAL_IP:2000 ppman list"
    echo "   node index.js -u http://$EXTERNAL_IP:2000 ppman install python node"
    echo ""
    echo "2. Test the API:"
    echo "   curl http://$EXTERNAL_IP:2000/api/v2/runtimes"
    echo ""
    echo "3. View logs:"
    echo "   kubectl logs -n piston -l app=piston-api -f"
    echo ""
    echo "4. Scale deployment:"
    echo "   kubectl scale deployment piston-api -n piston --replicas=3"
}

main() {
    log_info "Starting Piston GCP Deployment"
    log_info "Project: $PROJECT_ID"
    log_info "Region: $REGION"
    log_info "Zone: $ZONE"
    echo ""
    
    check_prerequisites
    set_project
    enable_apis
    create_filestore
    create_gke_cluster
    get_cluster_credentials
    update_filestore_ip
    deploy_piston
    wait_for_pods
    wait_for_loadbalancer
    display_summary
    
    log_info "Deployment completed successfully!"
}

# Run main function
main

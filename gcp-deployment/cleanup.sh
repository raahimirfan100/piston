#!/usr/bin/env bash

# Cleanup script for Piston GCP deployment

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_ID="${PROJECT_ID:-}"
ZONE="${ZONE:-us-central1-a}"
CLUSTER_NAME="${CLUSTER_NAME:-piston-cluster}"
FILESTORE_NAME="${FILESTORE_NAME:-piston-packages}"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

if [ -z "$PROJECT_ID" ]; then
    log_error "PROJECT_ID not set. Please set it before running."
    echo "Usage: PROJECT_ID=your-project-id $0"
    exit 1
fi

log_warn "This will delete all Piston resources in project $PROJECT_ID"
read -p "Are you sure? (yes/no) " -r
echo

if [[ ! $REPLY =~ ^yes$ ]]; then
    log_info "Cleanup cancelled"
    exit 0
fi

log_info "Deleting Kubernetes resources..."
kubectl delete namespace piston --ignore-not-found=true

log_info "Deleting GKE cluster..."
gcloud container clusters delete "$CLUSTER_NAME" \
    --zone="$ZONE" \
    --project="$PROJECT_ID" \
    --quiet || log_warn "Cluster deletion failed or cluster doesn't exist"

log_info "Deleting Filestore instance..."
gcloud filestore instances delete "$FILESTORE_NAME" \
    --zone="$ZONE" \
    --project="$PROJECT_ID" \
    --quiet || log_warn "Filestore deletion failed or instance doesn't exist"

log_info "Cleanup complete!"

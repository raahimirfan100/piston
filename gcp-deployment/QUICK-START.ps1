# ============================================
# PISTON EVENT - QUICK START SCRIPT
# ============================================
# Run this tomorrow morning before your event
# Total time: 8-10 minutes
# ============================================

$ErrorActionPreference = "Stop"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  PISTON GCP DEPLOYMENT - EVENT MODE" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Configuration
$PROJECT_ID = "piston-prod-4555"
$ZONE = "us-central1-a"
$CLUSTER_NAME = "piston-cluster"

Write-Host "Step 1/7: Setting GCP project..." -ForegroundColor Yellow
gcloud config set project $PROJECT_ID

Write-Host "`nStep 2/7: Creating GKE cluster (8-10 minutes)..." -ForegroundColor Yellow
Write-Host "Machine type: n2-standard-4 (4 vCPU, 16GB RAM)" -ForegroundColor Gray
gcloud container clusters create $CLUSTER_NAME `
    --zone=$ZONE `
    --machine-type=n2-standard-4 `
    --num-nodes=2 `
    --enable-autoscaling --min-nodes=2 --max-nodes=8 `
    --enable-autorepair --enable-autoupgrade `
    --enable-ip-alias `
    --disk-size=50 --disk-type=pd-ssd `
    --quiet

Write-Host "`nStep 3/7: Getting cluster credentials..." -ForegroundColor Yellow
gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE

Write-Host "`nStep 4/7: Applying Kubernetes resources..." -ForegroundColor Yellow
kubectl apply -f namespace.yaml
kubectl apply -f pvc-simple.yaml
kubectl apply -f configmap.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

Write-Host "`nStep 5/7: Waiting for pod to be ready (2-3 minutes)..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=piston-api -n piston --timeout=300s

Write-Host "`nStep 6/7: Installing language packages (3-4 minutes)..." -ForegroundColor Yellow
$languages = @("python=3.12.0", "node=20.11.1", "typescript=5.0.3", "java=15.0.2", "go=1.16.2", "rust=1.68.2", "gcc=10.2.0")
foreach ($lang in $languages) {
    Write-Host "  Installing $lang..." -ForegroundColor Gray
    kubectl exec -n piston deployment/piston-api -- node /piston/cli/index.js ppman install $lang
}

Write-Host "`nStep 7/7: Getting service IP..." -ForegroundColor Yellow
Start-Sleep -Seconds 10
$SERVICE_IP = kubectl get svc piston-api -n piston -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nAPI URL: http://${SERVICE_IP}:2000" -ForegroundColor Cyan
Write-Host "`nTest with:" -ForegroundColor Yellow
Write-Host "  curl http://${SERVICE_IP}:2000/api/v2/runtimes" -ForegroundColor White
Write-Host "`nLanguages installed:" -ForegroundColor Yellow
Write-Host "  Python 3.12.0, Node.js 20.11.1, TypeScript 5.0.3," -ForegroundColor White
Write-Host "  Java 15.0.2, Go 1.16.2, Rust 1.68.2, C/C++ GCC 10.2.0" -ForegroundColor White
Write-Host "`nMonitor with:" -ForegroundColor Yellow
Write-Host "  kubectl get pods -n piston" -ForegroundColor White
Write-Host "  kubectl logs -n piston deployment/piston-api -f" -ForegroundColor White
Write-Host "`n"

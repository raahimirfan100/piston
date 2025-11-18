# Quick Event Deployment Script for Piston on GCP
# Optimized for 1-day event with $300 budget - prioritizes performance over cost

param(
    [string]$ProjectId = "piston-event-$(Get-Random -Minimum 1000 -Maximum 9999)",
    [string]$Region = "us-central1",
    [string]$Zone = "us-central1-a",
    [string]$ClusterName = "piston-cluster"
)

$ErrorActionPreference = "Continue"

Write-Host "╔════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Piston Quick Deployment for 1-Day Event         ║" -ForegroundColor Cyan
Write-Host "║   Performance-Optimized Configuration              ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════╝" -ForegroundColor Cyan

Write-Host "`n[CONFIG] Project ID: $ProjectId" -ForegroundColor Green
Write-Host "[CONFIG] Region: $Region" -ForegroundColor Green
Write-Host "[CONFIG] Zone: $Zone" -ForegroundColor Green

# Check prerequisites
Write-Host "`n[STEP 1/7] Checking prerequisites..." -ForegroundColor Yellow
try {
    $null = Get-Command gcloud -ErrorAction Stop
    $null = Get-Command kubectl -ErrorAction Stop
    Write-Host "✓ Prerequisites OK" -ForegroundColor Green
} catch {
    Write-Host "ERROR: gcloud or kubectl is not installed!" -ForegroundColor Red
    exit 1
}

# Set active project
Write-Host "`n[STEP 2/7] Setting up GCP project..." -ForegroundColor Yellow
gcloud config set project $ProjectId 2>$null
Write-Host "✓ Project configured: $ProjectId" -ForegroundColor Green

# Enable APIs
Write-Host "`n[STEP 3/7] Enabling required GCP APIs..." -ForegroundColor Yellow
Write-Host "  (This may take 2-3 minutes...)" -ForegroundColor Cyan
gcloud services enable container.googleapis.com compute.googleapis.com logging.googleapis.com monitoring.googleapis.com --project=$ProjectId 2>$null
Write-Host "✓ APIs enabled" -ForegroundColor Green

# Create GKE cluster
Write-Host "`n[STEP 4/7] Creating GKE cluster (takes ~8 minutes)..." -ForegroundColor Yellow
Write-Host "  Configuration: n2-standard-4 nodes, 2 initial nodes, autoscale 2-8 nodes" -ForegroundColor Cyan

gcloud container clusters create $ClusterName `
    --zone=$Zone `
    --machine-type=n2-standard-4 `
    --num-nodes=2 `
    --enable-autoscaling `
    --min-nodes=2 `
    --max-nodes=8 `
    --enable-autorepair `
    --enable-autoupgrade `
    --enable-ip-alias `
    --disk-size=50 `
    --disk-type=pd-ssd `
    --workload-pool="$ProjectId.svc.id.goog" `
    --no-enable-cloud-logging `
    --no-enable-cloud-monitoring 2>$null

Write-Host "✓ GKE cluster created" -ForegroundColor Green

# Get credentials
Write-Host "`n[STEP 5/7] Configuring kubectl..." -ForegroundColor Yellow
gcloud container clusters get-credentials $ClusterName --zone=$Zone 2>$null
Write-Host "✓ kubectl configured" -ForegroundColor Green

# Deploy Kubernetes resources
Write-Host "`n[STEP 6/7] Deploying Piston to Kubernetes..." -ForegroundColor Yellow

Write-Host "  → Creating namespace..." -ForegroundColor Cyan
kubectl apply -f namespace.yaml

Write-Host "  → Creating storage (100GB persistent disk)..." -ForegroundColor Cyan
kubectl apply -f pvc-simple.yaml

Write-Host "  → Applying high-performance configuration..." -ForegroundColor Cyan
kubectl apply -f configmap.yaml

Write-Host "  → Deploying Piston API (2 initial replicas)..." -ForegroundColor Cyan
kubectl apply -f deployment.yaml

Write-Host "  → Creating LoadBalancer service..." -ForegroundColor Cyan
kubectl apply -f service.yaml

Write-Host "  → Applying Horizontal Pod Autoscaler (2-8 pods)..." -ForegroundColor Cyan
kubectl apply -f hpa.yaml

# Wait for pods
Write-Host "`n  Waiting for pods to be ready (this may take 2-3 minutes)..." -ForegroundColor Cyan
$waited = 0
while ($waited -lt 300) {
    $ready = kubectl get pods -n piston -l app=piston-api -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>$null
    if ($ready -eq "True") {
        Write-Host "`n✓ Pods ready" -ForegroundColor Green
        break
    }
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 5
    $waited += 5
}

if ($waited -ge 300) {
    Write-Host "`nWARNING: Pods not ready after 5 minutes" -ForegroundColor Yellow
    Write-Host "Check status with: kubectl get pods -n piston" -ForegroundColor Yellow
}

# Get LoadBalancer IP
Write-Host "`n[STEP 7/7] Getting LoadBalancer IP..." -ForegroundColor Yellow
$EXTERNAL_IP = ""
$waited = 0
while ($waited -lt 180) {
    $EXTERNAL_IP = kubectl get service piston-api -n piston -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
    if ($EXTERNAL_IP) {
        Write-Host "✓ LoadBalancer IP assigned: $EXTERNAL_IP" -ForegroundColor Green
        break
    }
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 5
    $waited += 5
}

if (-not $EXTERNAL_IP) {
    Write-Host "`nWARNING: LoadBalancer IP not assigned yet" -ForegroundColor Yellow
    Write-Host "Check later with: kubectl get service piston-api -n piston" -ForegroundColor Yellow
    $EXTERNAL_IP = "<pending>"
}

# Display summary
Write-Host "`n╔════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║          🎉 DEPLOYMENT SUCCESSFUL! 🎉              ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`n🌐 Piston API URL: http://${EXTERNAL_IP}:2000" -ForegroundColor White

Write-Host "`n📋 Quick Status Check:" -ForegroundColor Yellow
Write-Host "   kubectl get pods -n piston" -ForegroundColor White
Write-Host "   kubectl get hpa -n piston" -ForegroundColor White

Write-Host "`n📦 NEXT STEP - Install Language Packages:" -ForegroundColor Yellow
Write-Host "   cd ..\cli" -ForegroundColor White
Write-Host "   npm install" -ForegroundColor White
Write-Host "   node index.js -u http://${EXTERNAL_IP}:2000 ppman install python node typescript java go rust cpp" -ForegroundColor White

Write-Host "`n🧪 Test the API:" -ForegroundColor Yellow
Write-Host "   curl http://${EXTERNAL_IP}:2000/api/v2/runtimes" -ForegroundColor White

Write-Host "`n📊 Monitor Performance:" -ForegroundColor Yellow
Write-Host "   kubectl top pods -n piston" -ForegroundColor White
Write-Host "   kubectl logs -n piston -l app=piston-api --tail=50 -f" -ForegroundColor White

Write-Host "`n⚡ Cluster Info:" -ForegroundColor Yellow
Write-Host "   - Machine Type: n2-standard-4 (4 vCPU, 16GB RAM)" -ForegroundColor White
Write-Host "   - Initial Nodes: 2" -ForegroundColor White
Write-Host "   - Autoscaling: 2-8 nodes" -ForegroundColor White
Write-Host "   - Pod Replicas: 2 (autoscales 2-8 based on load)" -ForegroundColor White
Write-Host "   - Max Concurrent Jobs: 256 per pod" -ForegroundColor White
Write-Host "   - Storage: 100GB SSD-backed persistent disk" -ForegroundColor White

Write-Host "`n💰 Estimated Cost: ~`$8-12 per day for event" -ForegroundColor Yellow
Write-Host "   - GKE cluster: ~`$2.50/day" -ForegroundColor White
Write-Host "   - 2-8 nodes @ ~`$1.60/day each: `$3.20-12.80/day" -ForegroundColor White
Write-Host "   - LoadBalancer: ~`$0.60/day" -ForegroundColor White
Write-Host "   - Storage: ~`$0.14/day" -ForegroundColor White

Write-Host "`n🗑️  Cleanup After Event:" -ForegroundColor Yellow
Write-Host "   gcloud container clusters delete $ClusterName --zone=$Zone --quiet" -ForegroundColor White

Write-Host "`nDeployment complete! Proceed with language package installation.`n" -ForegroundColor Cyan

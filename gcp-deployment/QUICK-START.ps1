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

Write-Host "`nStep 6/8: Getting service IP..." -ForegroundColor Yellow
Start-Sleep -Seconds 10
$SERVICE_IP = kubectl get svc piston-api -n piston -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

Write-Host "`nStep 7/8: Installing language packages via API (3-6 minutes)..." -ForegroundColor Yellow
Write-Host "Service IP: $SERVICE_IP" -ForegroundColor Gray
Write-Host "Checking available packages..." -ForegroundColor Gray
$available = Invoke-RestMethod -Method Get -Uri "http://$SERVICE_IP:2000/api/v2/packages"

$desired = @(
    @{ language = "python"; version = "3.12.0" },
    @{ language = "node"; version = "20.11.1" },
    @{ language = "typescript"; version = "5.0.3" },
    @{ language = "java"; version = "15.0.2" },
    @{ language = "go"; version = "1.16.2" },
    @{ language = "rust"; version = "1.68.2" },
    @{ language = "gcc"; version = "10.2.0" }
)

foreach ($pkg in $desired) {
    $already = $available | Where-Object { $_.language -eq $pkg.language -and $_.language_version -eq $pkg.version -and $_.installed }
    if ($already) {
        Write-Host "  Skipping $($pkg.language) $($pkg.version) (already installed)" -ForegroundColor DarkGray
        continue
    }
    Write-Host "  Installing $($pkg.language) $($pkg.version)..." -ForegroundColor Gray
    try {
        $body = $pkg | ConvertTo-Json
        $resp = Invoke-RestMethod -Method Post -Uri "http://$SERVICE_IP:2000/api/v2/packages" -Body $body -ContentType "application/json" -TimeoutSec 600
        Write-Host "    -> Installed $($resp.language) $($resp.version)" -ForegroundColor Green
    }
    catch {
        Write-Host "    !! Failed $($pkg.language) $($pkg.version): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nStep 8/8: Verifying runtimes..." -ForegroundColor Yellow
$runtimes = Invoke-RestMethod -Method Get -Uri "http://$SERVICE_IP:2000/api/v2/runtimes"
Write-Host "Installed runtimes count: $($runtimes.Count)" -ForegroundColor Cyan
if ($runtimes.Count -eq 0) { Write-Host "WARNING: No runtimes installed" -ForegroundColor Red }

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nAPI URL: http://${SERVICE_IP}:2000" -ForegroundColor Cyan
Write-Host "`nTest runtimes:" -ForegroundColor Yellow
Write-Host "  curl http://${SERVICE_IP}:2000/api/v2/runtimes" -ForegroundColor White
Write-Host "`nInstall status summary:" -ForegroundColor Yellow
foreach ($pkg in $desired) { Write-Host "  $($pkg.language) $($pkg.version)" -ForegroundColor White }
Write-Host "`nMonitor with:" -ForegroundColor Yellow
Write-Host "  kubectl get pods -n piston" -ForegroundColor White
Write-Host "  kubectl logs -n piston deployment/piston-api -f" -ForegroundColor White
Write-Host "`n"

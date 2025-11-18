# ============================================
# PISTON EVENT - SHUTDOWN SCRIPT
# ============================================
# Run this tonight to minimize costs
# ============================================

$ErrorActionPreference = "Stop"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  PISTON GCP SHUTDOWN" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$PROJECT_ID = "piston-prod-4555"
$ZONE = "us-central1-a"
$CLUSTER_NAME = "piston-cluster"

Write-Host "This will delete the GKE cluster to save costs." -ForegroundColor Yellow
Write-Host "Tomorrow: Run QUICK-START.ps1 to recreate (8-10 minutes)`n" -ForegroundColor Yellow

$confirmation = Read-Host "Type 'yes' to confirm deletion"

if ($confirmation -ne "yes") {
    Write-Host "`nShutdown cancelled." -ForegroundColor Red
    exit 1
}

Write-Host "`nSetting project..." -ForegroundColor Yellow
gcloud config set project $PROJECT_ID

Write-Host "`nDeleting cluster (2-3 minutes)..." -ForegroundColor Yellow
gcloud container clusters delete $CLUSTER_NAME --zone=$ZONE --quiet

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  SHUTDOWN COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nIdle cost: `$0/day" -ForegroundColor Cyan
Write-Host "`nTo restart tomorrow:" -ForegroundColor Yellow
Write-Host "  cd gcp-deployment" -ForegroundColor White
Write-Host "  .\QUICK-START.ps1" -ForegroundColor White
Write-Host "`n"

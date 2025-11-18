# Quick Start Guide for Windows PowerShell

# 1. Set your project configuration
$env:PROJECT_ID = "piston-prod-$(Get-Random -Maximum 9999)"  # Change this to your desired project ID
$env:REGION = "us-central1"
$env:ZONE = "us-central1-a"
$env:CLUSTER_NAME = "piston-cluster"
$env:FILESTORE_NAME = "piston-packages"

Write-Host "Project ID: $env:PROJECT_ID" -ForegroundColor Green
Write-Host "Region: $env:REGION" -ForegroundColor Green
Write-Host "Zone: $env:ZONE" -ForegroundColor Green

# 2. Set active project
gcloud config set project $env:PROJECT_ID

# 3. Enable required APIs
Write-Host "`nEnabling required APIs..." -ForegroundColor Yellow
gcloud services enable container.googleapis.com compute.googleapis.com file.googleapis.com logging.googleapis.com monitoring.googleapis.com

# 4. Create Filestore instance
Write-Host "`nCreating Filestore instance (this takes ~5 minutes)..." -ForegroundColor Yellow
gcloud filestore instances create $env:FILESTORE_NAME `
    --zone=$env:ZONE `
    --tier=BASIC_HDD `
    --file-share=name="packages",capacity=1TB `
    --network=name="default"

# 5. Create GKE cluster
Write-Host "`nCreating GKE cluster (this takes ~5-10 minutes)..." -ForegroundColor Yellow
gcloud container clusters create $env:CLUSTER_NAME `
    --zone=$env:ZONE `
    --machine-type=n2-standard-4 `
    --num-nodes=2 `
    --enable-autoscaling `
    --min-nodes=1 `
    --max-nodes=5 `
    --enable-autorepair `
    --enable-autoupgrade `
    --enable-ip-alias `
    --workload-pool="$env:PROJECT_ID.svc.id.goog" `
    --addons=GcpFilestoreCsiDriver

# 6. Get cluster credentials
Write-Host "`nConfiguring kubectl..." -ForegroundColor Yellow
gcloud container clusters get-credentials $env:CLUSTER_NAME --zone=$env:ZONE

# 7. Update PV manifest with Filestore IP
Write-Host "`nUpdating PersistentVolume manifest..." -ForegroundColor Yellow
$FILESTORE_IP = gcloud filestore instances describe $env:FILESTORE_NAME --zone=$env:ZONE --format="value(networks[0].ipAddresses[0])"
Write-Host "Filestore IP: $FILESTORE_IP" -ForegroundColor Green
(Get-Content pv.yaml) -replace 'FILESTORE_IP_PLACEHOLDER', $FILESTORE_IP | Set-Content pv.yaml

# 8. Deploy Piston
Write-Host "`nDeploying Piston to Kubernetes..." -ForegroundColor Yellow
kubectl apply -f namespace.yaml
kubectl apply -f pv.yaml
kubectl apply -f pvc.yaml
kubectl apply -f configmap.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# 9. Wait for pods
Write-Host "`nWaiting for pods to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=piston-api -n piston --timeout=300s

# 10. Get LoadBalancer IP
Write-Host "`nWaiting for LoadBalancer IP..." -ForegroundColor Yellow
Start-Sleep -Seconds 30
$EXTERNAL_IP = ""
for ($i = 0; $i -lt 60; $i++) {
    $EXTERNAL_IP = kubectl get service piston-api -n piston -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
    if ($EXTERNAL_IP) { break }
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 5
}

Write-Host "`n`n========================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nPiston API URL: http://${EXTERNAL_IP}:2000"
Write-Host "Runtimes endpoint: http://${EXTERNAL_IP}:2000/api/v2/runtimes"
Write-Host "`nNext steps:"
Write-Host "1. Install language packages:"
Write-Host "   cd ..\cli; npm install"
Write-Host "   node index.js -u http://${EXTERNAL_IP}:2000 ppman install python node"
Write-Host "`n2. Test the API:"
Write-Host "   curl http://${EXTERNAL_IP}:2000/api/v2/runtimes"

# Cost-Optimized Deployment for GCP Free Tier ($300 credits)

## Changes Made for Cost Optimization

1. **No Filestore**: Using standard persistent disk (ReadWriteOnce) instead of Filestore
   - Saves ~$200/month
   - Single replica deployment to work with ReadWriteOnce

2. **Smaller Machine Types**: e2-medium (2 vCPU, 4GB RAM)
   - Much cheaper than n2-standard-4
   - Sufficient for testing and light workloads

3. **Reduced Node Count**: 1-2 nodes instead of 2-5
   - Minimal cluster size
   - Can scale up if needed

4. **Smaller Storage**: 100GB instead of 1TB
   - More than enough for language packages
   - Can expand later if needed

5. **Single Replica**: 1 pod instead of 2
   - Reduces compute costs
   - Can scale manually when needed

## Estimated Monthly Costs

- **GKE Cluster**: ~$75/month (management fee + 1-2 e2-medium nodes)
- **Persistent Disk**: ~$4/month (100GB standard)
- **LoadBalancer**: ~$18/month
- **Total**: ~$97/month (leaves plenty of free tier credits)

## Quick Deploy Commands

```powershell
# Set variables
$env:PROJECT_ID = "piston-prod-4555"
$env:ZONE = "us-central1-a"
$env:CLUSTER_NAME = "piston-cluster"

# Create GKE cluster (cost-optimized)
gcloud container clusters create $env:CLUSTER_NAME `
    --zone=$env:ZONE `
    --machine-type=e2-medium `
    --num-nodes=1 `
    --disk-size=30 `
    --enable-autoscaling `
    --min-nodes=1 `
    --max-nodes=2 `
    --enable-autorepair `
    --enable-autoupgrade

# Get credentials
gcloud container clusters get-credentials $env:CLUSTER_NAME --zone=$env:ZONE

# Deploy (using simple PVC instead of Filestore)
kubectl apply -f namespace.yaml
kubectl apply -f pvc-simple.yaml
kubectl apply -f configmap.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# Wait for deployment
kubectl wait --for=condition=ready pod -l app=piston-api -n piston --timeout=300s

# Get external IP
kubectl get service piston-api -n piston
```

## Scaling Up Later

If you need more capacity:

```powershell
# Scale to 2 replicas (requires Filestore for ReadWriteMany)
kubectl scale deployment piston-api -n piston --replicas=2

# Or add more nodes
gcloud container clusters resize $env:CLUSTER_NAME --num-nodes=2 --zone=$env:ZONE
```

## Cost Monitoring

Check your spending:
```powershell
gcloud billing accounts list
gcloud billing projects describe $env:PROJECT_ID
```

Set up budget alerts in Cloud Console to track your $300 credits.

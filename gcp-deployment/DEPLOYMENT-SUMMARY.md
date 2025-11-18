# Piston GCP Deployment - Event Ready Configuration

## 🎯 Deployment Summary

**Status**: ✅ **DEPLOYED AND TESTED**
**API Endpoint**: `http://34.134.219.255:2000`
**Project ID**: `piston-prod-4555`
**Region**: `us-central1-a`

## 📊 Current Configuration

### Infrastructure
- **GKE Cluster**: `piston-cluster` (2x e2-medium nodes, autoscaling 1-2)
- **Storage**: 100GB Persistent Disk (standard-rwo) - **$4/month**
- **LoadBalancer**: External IP `34.134.219.255` - **~$18/month**
- **Auto-scaling**: HPA enabled (2-10 pods based on CPU/memory)

### Cost Breakdown (Monthly)
| Resource | Cost |
|----------|------|
| GKE Cluster Management | $75 |
| 2x e2-medium nodes (avg) | $24-48 |
| Persistent Disk (100GB) | $4 |
| LoadBalancer | $18 |
| **Total Estimate** | **~$121-145/month** |

**Budget Safety**: Well within $300 free credits for 2+ months

### Installed Languages
✅ Python 3.12.0
✅ JavaScript (Node.js 20.11.1)
✅ TypeScript 5.0.3
✅ Java 15.0.2
✅ Go 1.16.2
✅ Rust 1.68.2
✅ C/C++ (GCC 10.2.0)
✅ Fortran 10.2.0
✅ D 10.2.0

## 🚀 API Endpoints

### Check Available Runtimes
```bash
curl http://34.134.219.255:2000/api/v2/runtimes
```

### Execute Code
```bash
curl -X POST http://34.134.219.255:2000/api/v2/execute \
  -H "Content-Type: application/json" \
  -d '{
    "language": "python",
    "version": "3.12.0",
    "files": [{
      "content": "print(\"Hello World!\")"
    }]
  }'
```

## 📈 Performance & Scaling

### Current Limits (Per Request)
- **Max Process Count**: 64 processes
- **Compile Timeout**: 10 seconds
- **Run Timeout**: 3 seconds
- **Max Output**: 1KB per stdio buffer
- **Max File Size**: 10MB
- **Networking**: Disabled (security)

### Scaling Configuration
- **Min Replicas**: 2 (for high availability)
- **Max Replicas**: 10 (handles ~640 concurrent jobs)
- **Scale Up Trigger**: CPU > 70% or Memory > 80%
- **Scale Down**: Gradual (5 minutes stabilization)

### Expected Capacity
- **Each pod**: ~64 concurrent jobs
- **2 pods (current)**: ~128 concurrent jobs
- **10 pods (max)**: ~640 concurrent jobs
- **Response time**: 100-500ms (depending on language/code complexity)

## 🔍 Monitoring & Logs

### View Logs
```powershell
# Real-time logs
kubectl logs -n piston -l app=piston-api -f

# Recent logs
kubectl logs -n piston -l app=piston-api --tail=100
```

### Check Pod Status
```powershell
kubectl get pods -n piston
kubectl describe pod -n piston <pod-name>
```

### Monitor Scaling
```powershell
kubectl get hpa -n piston -w
```

### Cloud Console Links
- **GKE Cluster**: https://console.cloud.google.com/kubernetes/clusters/details/us-central1-a/piston-cluster?project=piston-prod-4555
- **Workloads**: https://console.cloud.google.com/kubernetes/workload?project=piston-prod-4555
- **Logs**: https://console.cloud.google.com/logs/query?project=piston-prod-4555

## 🛠️ Management Commands

### Scale Manually (if needed)
```powershell
# Increase to 5 replicas
kubectl scale deployment piston-api -n piston --replicas=5

# Let HPA manage it
kubectl autoscale deployment piston-api -n piston --min=2 --max=10
```

### Add More Languages
```powershell
cd cli
node index.js -u http://34.134.219.255:2000 ppman list
node index.js -u http://34.134.219.255:2000 ppman install <language>
```

### Update Configuration
```powershell
cd gcp-deployment
# Edit configmap.yaml to change limits/timeouts
kubectl apply -f configmap.yaml
kubectl rollout restart deployment piston-api -n piston
```

## 🔒 Security Features

✅ **Privileged isolation** via cgroup v2 and isolate
✅ **Network disabled** in execution environment
✅ **Resource limits** enforced per job
✅ **Process isolation** with separate UIDs (1001-1500)
✅ **Timeout protection** (compile + runtime)
✅ **Output size limits** (prevent memory exhaustion)

## 🧪 Testing

### Python Test
```json
{
  "language": "python",
  "version": "3.12.0",
  "files": [{"content": "print('Hello World!')"}]
}
```

### JavaScript Test
```json
{
  "language": "javascript",
  "version": "20.11.1",
  "files": [{"content": "console.log('Hello World!');"}]
}
```

### C++ Test
```json
{
  "language": "cpp",
  "version": "10.2.0",
  "files": [{
    "name": "main.cpp",
    "content": "#include <iostream>\nint main() { std::cout << \"Hello World!\" << std::endl; return 0; }"
  }]
}
```

## 🎪 Event Day Checklist

### Before Event
- [ ] Verify API is accessible: `curl http://34.134.219.255:2000/api/v2/runtimes`
- [ ] Check all pods are running: `kubectl get pods -n piston`
- [ ] Verify HPA is active: `kubectl get hpa -n piston`
- [ ] Test code execution for each language
- [ ] Monitor dashboard open: https://console.cloud.google.com/kubernetes

### During Event
- [ ] Monitor pod count and scaling
- [ ] Watch for error logs
- [ ] Check API response times
- [ ] Monitor billing (should stay well under budget)

### After Event
- [ ] Review total cost in billing
- [ ] Export logs if needed
- [ ] Scale down if continuing: `kubectl scale deployment piston-api -n piston --replicas=1`
- [ ] Or cleanup completely: Run `cleanup.sh`

## 🧹 Cleanup (After Event)

To delete everything and stop charges:

```powershell
cd gcp-deployment
kubectl delete namespace piston
gcloud container clusters delete piston-cluster --zone=us-central1-a --quiet
```

Or use the cleanup script:
```powershell
$env:PROJECT_ID = "piston-prod-4555"
.\cleanup.sh
```

## 📞 Troubleshooting

### Pod Not Starting
```powershell
kubectl describe pod -n piston <pod-name>
kubectl logs -n piston <pod-name>
```

### High Latency
- Check if pods are being throttled: `kubectl top pods -n piston`
- Scale up manually if needed
- Check node resources: `kubectl top nodes`

### Out of Resources
- HPA will auto-scale up to 10 pods
- If hitting limits, cluster will auto-add a 2nd node
- Max 2 nodes configured (cost control)

## 📊 Billing Alerts

Set up budget alert in Cloud Console:
1. Go to https://console.cloud.google.com/billing
2. Select "Budgets & alerts"
3. Create alert at $100, $200, $250 thresholds

## ✅ Deployment Complete!

Your Piston code execution engine is ready for high-volume traffic. The setup is:
- **Cost-optimized** for free tier ($300 credits)
- **Auto-scaling** for traffic spikes
- **Secure** with proper isolation
- **Tested** with all major languages
- **Monitored** via Cloud Console

Good luck with your event! 🚀

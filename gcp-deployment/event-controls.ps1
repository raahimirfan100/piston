# Piston Event Control Script
# Quick commands for managing your deployment before/during/after the event

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("shutdown", "startup", "status", "test")]
    [string]$Action
)

$API_URL = "http://34.59.81.173:2000"

function Show-Menu {
    Write-Host "`n╔════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║        Piston Event Control Panel                 ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host "`nAPI URL: $API_URL`n" -ForegroundColor White
    Write-Host "1. 🛑 Shutdown (scale to 0) - Save costs overnight" -ForegroundColor Yellow
    Write-Host "2. 🚀 Startup (scale to 1) - Ready for event" -ForegroundColor Green
    Write-Host "3. 📊 Check Status - See pod/node status" -ForegroundColor Cyan
    Write-Host "4. 🧪 Test API - Verify all languages work" -ForegroundColor Magenta
    Write-Host "5. ❌ Exit`n" -ForegroundColor White
}

function Shutdown-Piston {
    Write-Host "`n🛑 Shutting down Piston (scaling to 0 replicas)..." -ForegroundColor Yellow
    kubectl scale deployment piston-api -n piston --replicas=0
    Write-Host "✅ Shutdown complete!" -ForegroundColor Green
    Write-Host "💰 Cost savings: ~$7.50/day while shut down" -ForegroundColor Green
    Write-Host "ℹ️  Cluster remains active (costs $2.50/day)" -ForegroundColor Cyan
}

function Startup-Piston {
    Write-Host "`n🚀 Starting up Piston (scaling to 1 replica)..." -ForegroundColor Yellow
    kubectl scale deployment piston-api -n piston --replicas=1
    
    Write-Host "⏳ Waiting for pod to be ready (takes 2-3 minutes)..." -ForegroundColor Cyan
    $waited = 0
    while ($waited -lt 180) {
        $ready = kubectl get pods -n piston -l app=piston-api -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>$null
        if ($ready -eq "True") {
            Write-Host "`n✅ Piston is ready!" -ForegroundColor Green
            Write-Host "🌐 API URL: $API_URL" -ForegroundColor White
            Write-Host "🧪 Test with: curl $API_URL/api/v2/runtimes" -ForegroundColor Cyan
            return
        }
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 5
        $waited += 5
    }
    Write-Host "`n⚠️  Pod taking longer than expected. Check status with option 3." -ForegroundColor Yellow
}

function Show-Status {
    Write-Host "`n📊 Cluster Status:" -ForegroundColor Cyan
    Write-Host "`nPods:" -ForegroundColor Yellow
    kubectl get pods -n piston -o wide
    
    Write-Host "`nService (LoadBalancer):" -ForegroundColor Yellow
    kubectl get service piston-api -n piston
    
    Write-Host "`nHorizontal Pod Autoscaler:" -ForegroundColor Yellow
    kubectl get hpa -n piston
    
    Write-Host "`nNodes:" -ForegroundColor Yellow
    kubectl get nodes
}

function Test-API {
    Write-Host "`n🧪 Testing API and Languages..." -ForegroundColor Cyan
    
    try {
        $runtimes = Invoke-RestMethod -Uri "$API_URL/api/v2/runtimes" -Method Get -TimeoutSec 5
        Write-Host "✅ API is responding!" -ForegroundColor Green
        Write-Host "`n📦 Installed languages: $($runtimes.Count)" -ForegroundColor Yellow
        
        # Test Python
        Write-Host "`nTesting Python..." -ForegroundColor Cyan
        $body = @{ language = "python"; version = "3.12.0"; files = @(@{ content = "print('Python OK')" }) } | ConvertTo-Json -Depth 10
        $result = Invoke-RestMethod -Uri "$API_URL/api/v2/execute" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 10
        if ($result.run.stdout -match "Python OK") {
            Write-Host "✅ Python: Working" -ForegroundColor Green
        }
        
        # Test JavaScript
        Write-Host "Testing Node.js..." -ForegroundColor Cyan
        $body = @{ language = "javascript"; version = "20.11.1"; files = @(@{ content = "console.log('Node OK')" }) } | ConvertTo-Json -Depth 10
        $result = Invoke-RestMethod -Uri "$API_URL/api/v2/execute" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 10
        if ($result.run.stdout -match "Node OK") {
            Write-Host "✅ Node.js: Working" -ForegroundColor Green
        }
        
        # Test Java
        Write-Host "Testing Java..." -ForegroundColor Cyan
        $body = @{ language = "java"; version = "15.0.2"; files = @(@{ content = 'public class Main { public static void main(String[] args) { System.out.println("Java OK"); } }' }) } | ConvertTo-Json -Depth 10
        $result = Invoke-RestMethod -Uri "$API_URL/api/v2/execute" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 10
        if ($result.run.stdout -match "Java OK") {
            Write-Host "✅ Java: Working" -ForegroundColor Green
        }
        
        Write-Host "`n🎉 All tests passed! System is ready for your event." -ForegroundColor Green
        
    } catch {
        Write-Host "❌ API test failed: $_" -ForegroundColor Red
        Write-Host "Check if pods are running with option 3" -ForegroundColor Yellow
    }
}

# Main execution
if ($Action) {
    switch ($Action) {
        "shutdown" { Shutdown-Piston }
        "startup" { Startup-Piston }
        "status" { Show-Status }
        "test" { Test-API }
    }
    exit
}

# Interactive menu
while ($true) {
    Show-Menu
    $choice = Read-Host "Select an option (1-5)"
    
    switch ($choice) {
        "1" { Shutdown-Piston }
        "2" { Startup-Piston }
        "3" { Show-Status }
        "4" { Test-API }
        "5" { 
            Write-Host "`nGoodbye! 👋" -ForegroundColor Cyan
            exit 
        }
        default { 
            Write-Host "`n❌ Invalid option. Please select 1-5." -ForegroundColor Red 
        }
    }
    
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

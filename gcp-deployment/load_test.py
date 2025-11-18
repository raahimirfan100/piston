# Simple load test script for Piston
# Usage: python load_test.py

import requests
import time
import concurrent.futures
import statistics

API_URL = "http://34.134.219.255:2000"

test_payloads = [
    {
        "language": "python",
        "version": "3.12.0",
        "files": [{"content": "print(sum(range(100)))"}]
    },
    {
        "language": "javascript",
        "version": "20.11.1",
        "files": [{"content": "console.log(Array.from({length:100}, (_, i) => i).reduce((a, b) => a + b, 0));"}]
    },
    {
        "language": "cpp",
        "version": "10.2.0",
        "files": [{"name": "main.cpp", "content": "#include <iostream>\nint main() { int sum = 0; for(int i=0; i<100; i++) sum += i; std::cout << sum << std::endl; return 0; }"}]
    }
]

def execute_code(payload):
    start = time.time()
    try:
        response = requests.post(f"{API_URL}/api/v2/execute", json=payload, timeout=10)
        elapsed = time.time() - start
        return {
            "success": response.status_code == 200,
            "time": elapsed,
            "status_code": response.status_code
        }
    except Exception as e:
        elapsed = time.time() - start
        return {
            "success": False,
            "time": elapsed,
            "error": str(e)
        }

def run_load_test(concurrent_requests=50, total_requests=200):
    print(f"\n=== Load Test: {concurrent_requests} concurrent, {total_requests} total ===\n")
    
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrent_requests) as executor:
        futures = []
        for i in range(total_requests):
            payload = test_payloads[i % len(test_payloads)]
            futures.append(executor.submit(execute_code, payload))
        
        for i, future in enumerate(concurrent.futures.as_completed(futures)):
            result = future.result()
            results.append(result)
            if (i + 1) % 50 == 0:
                print(f"Completed: {i + 1}/{total_requests}")
    
    # Calculate statistics
    successful = [r for r in results if r.get("success")]
    failed = [r for r in results if not r.get("success")]
    times = [r["time"] for r in successful]
    
    print(f"\n=== Results ===")
    print(f"Total requests: {total_requests}")
    print(f"Successful: {len(successful)} ({len(successful)/total_requests*100:.1f}%)")
    print(f"Failed: {len(failed)}")
    
    if times:
        print(f"\nResponse times:")
        print(f"  Min: {min(times):.3f}s")
        print(f"  Max: {max(times):.3f}s")
        print(f"  Mean: {statistics.mean(times):.3f}s")
        print(f"  Median: {statistics.median(times):.3f}s")
        print(f"  P95: {sorted(times)[int(len(times) * 0.95)]:.3f}s")
        print(f"  P99: {sorted(times)[int(len(times) * 0.99)]:.3f}s")

if __name__ == "__main__":
    # Check API is accessible
    try:
        response = requests.get(f"{API_URL}/api/v2/runtimes", timeout=5)
        print(f"API Status: {'✓ Online' if response.status_code == 200 else '✗ Error'}")
        print(f"Available runtimes: {len(response.json())}")
    except Exception as e:
        print(f"API Error: {e}")
        exit(1)
    
    # Run progressive load tests
    run_load_test(concurrent_requests=10, total_requests=50)
    time.sleep(5)
    run_load_test(concurrent_requests=25, total_requests=100)
    time.sleep(5)
    run_load_test(concurrent_requests=50, total_requests=200)

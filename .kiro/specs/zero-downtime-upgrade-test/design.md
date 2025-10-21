# Zero-Downtime Upgrade Test Plan - Design Document

## Overview

This document describes the design for a comprehensive test suite that validates zero-downtime upgrades for the Ray Serve vLLM deployment on EKS Auto Mode. The test suite will be implemented as a Bash script with supporting Kubernetes manifests and will validate that the high availability configuration maintains service availability during various disruption scenarios.

## Architecture

### Test Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Test Orchestrator                         │
│                   (Bash Script)                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Pre-Test     │  │ Test         │  │ Post-Test    │     │
│  │ Validation   │→ │ Execution    │→ │ Cleanup      │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                            ↓
        ┌───────────────────┼───────────────────┐
        ↓                   ↓                   ↓
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Load         │    │ Metrics      │    │ Ray Service  │
│ Generator    │    │ Collector    │    │ (Target)     │
│ (K6 Pod)     │    │ (Script)     │    │              │
└──────────────┘    └──────────────┘    └──────────────┘
```

### Component Details

1. **Test Orchestrator (Bash Script)**
   - Main test runner that coordinates all test scenarios
   - Validates pre-conditions before each test
   - Executes disruption scenarios
   - Collects and reports metrics
   - Performs cleanup and validation

2. **Load Generator (K6)**
   - Kubernetes Job that runs K6 load testing tool
   - Sends continuous inference requests to the service
   - Records response times, status codes, and errors
   - Outputs metrics in JSON format for analysis

3. **Metrics Collector (Bash Functions)**
   - Monitors pod status and transitions
   - Queries Kubernetes API for pod states
   - Calculates success rates and latency percentiles
   - Generates summary reports

4. **Ray Service (Target System)**
   - The deployed Ray Serve vLLM service
   - 3 worker pods with PodDisruptionBudget
   - 1 head pod with PodDisruptionBudget
   - 3 Redis pods with PodDisruptionBudget
   - Network Load Balancer for external access

## Test Scenarios

### Scenario 1: Pre-Test Validation
**Purpose**: Ensure the environment is correctly configured before testing

**Steps**:
1. Check Ray worker pod count (expect 3)
2. Check Ray head pod count (expect 1)
3. Check Redis pod count (expect 3)
4. Verify all PDBs exist and have correct minAvailable values
5. Verify NLB is provisioned and healthy
6. Verify worker pods are on different nodes
7. Execute baseline inference request

**Success Criteria**: All checks pass

### Scenario 2: Single Worker Pod Disruption
**Purpose**: Verify service remains available when one worker is disrupted

**Steps**:
1. Start load generator (5 req/s, 10 concurrent clients)
2. Wait 30 seconds for baseline metrics
3. Delete one worker pod
4. Monitor service availability for 5 minutes
5. Verify new pod becomes ready
6. Stop load generator
7. Collect and analyze metrics

**Success Criteria**:
- Success rate > 95% during disruption
- At least 2 workers remain running throughout
- New pod ready within 5 minutes
- Final state: 3 workers running

### Scenario 3: Node Drain Simulation
**Purpose**: Simulate node replacement during cluster upgrade

**Steps**:
1. Start load generator (5 req/s, 10 concurrent clients)
2. Wait 30 seconds for baseline metrics
3. Identify node with worker pod
4. Cordon the node
5. Drain the node (respecting PDBs)
6. Monitor service availability during drain
7. Wait for pod to reschedule and become ready
8. Uncordon the node
9. Stop load generator
10. Collect and analyze metrics

**Success Criteria**:
- Success rate > 90% during drain
- PDB prevents draining multiple workers simultaneously
- Pod terminates within 60 seconds
- New pod ready within 10 minutes
- Final state: 3 workers running

### Scenario 4: Sequential Worker Disruptions
**Purpose**: Simulate rolling upgrade across all workers

**Steps**:
1. Start load generator (5 req/s, 10 concurrent clients)
2. Wait 30 seconds for baseline metrics
3. For each of 3 workers:
   - Delete the worker pod
   - Wait 2 minutes for recovery
   - Verify at least 2 workers remain running
4. Stop load generator
5. Collect and analyze metrics

**Success Criteria**:
- Success rate > 90% throughout test
- At least 2 workers running at all times
- Total downtime < 30 seconds
- Final state: 3 workers running

### Scenario 5: Redis Pod Disruption
**Purpose**: Verify Ray GCS maintains state during Redis failure

**Steps**:
1. Start load generator (5 req/s, 10 concurrent clients)
2. Wait 30 seconds for baseline metrics
3. Delete one Redis pod
4. Monitor service availability for 3 minutes
5. Verify new Redis pod joins StatefulSet
6. Stop load generator
7. Collect and analyze metrics

**Success Criteria**:
- Success rate > 95% during disruption
- At least 2 Redis pods remain running
- Ray cluster remains operational
- New Redis pod ready within 2 minutes
- Final state: 3 Redis pods running

### Scenario 6: Head Pod Disruption
**Purpose**: Verify service recovers from head node failure

**Steps**:
1. Start load generator (5 req/s, 10 concurrent clients)
2. Wait 30 seconds for baseline metrics
3. Delete head pod
4. Monitor service availability for 5 minutes
5. Verify new head pod becomes ready
6. Verify workers reconnect to new head
7. Stop load generator
8. Collect and analyze metrics

**Success Criteria**:
- Temporary outage < 2 minutes
- New head pod ready within 3 minutes
- Workers reconnect within 1 minute
- Success rate > 95% after recovery
- Final state: 1 head pod running

## Implementation Details

### Load Generator Configuration

**K6 Script** (`test-load.js`):
```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const successRate = new Rate('success_rate');
const latency = new Trend('request_latency');

export const options = {
  scenarios: {
    constant_load: {
      executor: 'constant-vus',
      vus: 10,
      duration: '10m',
    },
  },
  thresholds: {
    'success_rate': ['rate>0.90'],
    'request_latency': ['p(95)<5000'],
  },
};

export default function () {
  const url = `http://${__ENV.NLB_ENDPOINT}/VLLMDeployment`;
  const payload = JSON.stringify({
    prompt: 'What is the capital of France?',
    max_tokens: 50,
    temperature: 0.7,
  });
  
  const params = {
    headers: { 'Content-Type': 'application/json' },
    timeout: '30s',
  };
  
  const start = Date.now();
  const res = http.post(url, payload, params);
  const duration = Date.now() - start;
  
  const success = check(res, {
    'status is 200': (r) => r.status === 200,
    'has generated_text': (r) => r.json('generated_text') !== undefined,
  });
  
  successRate.add(success);
  latency.add(duration);
  
  sleep(0.2); // 5 requests per second per VU
}
```

**K6 Job Manifest** (`k6-load-job.yaml`):
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: k6-load-test
  namespace: default
spec:
  ttlSecondsAfterFinished: 300
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: k6
        image: grafana/k6:latest
        command:
        - k6
        - run
        - --out
        - json=/tmp/results.json
        - /scripts/test-load.js
        env:
        - name: NLB_ENDPOINT
          value: "REPLACE_WITH_NLB_ENDPOINT"
        volumeMounts:
        - name: scripts
          mountPath: /scripts
        - name: results
          mountPath: /tmp
      volumes:
      - name: scripts
        configMap:
          name: k6-test-script
      - name: results
        emptyDir: {}
```

### Metrics Collection

**Bash Functions**:

```bash
# Get current pod count by label
get_pod_count() {
  local label=$1
  kubectl get pods -n default -l "$label" \
    --field-selector=status.phase=Running \
    -o json | jq '.items | length'
}

# Get pod ready status
get_pod_ready_count() {
  local label=$1
  kubectl get pods -n default -l "$label" \
    -o json | jq '[.items[] | select(.status.conditions[] | 
    select(.type=="Ready" and .status=="True"))] | length'
}

# Check if pods are on different nodes
check_pod_distribution() {
  local label=$1
  local pod_count=$(get_pod_count "$label")
  local node_count=$(kubectl get pods -n default -l "$label" \
    -o json | jq '[.items[].spec.nodeName] | unique | length')
  
  if [ "$pod_count" -eq "$node_count" ]; then
    echo "PASS: Pods distributed across $node_count nodes"
    return 0
  else
    echo "FAIL: $pod_count pods on $node_count nodes"
    return 1
  fi
}

# Execute test inference request
test_inference() {
  local nlb_endpoint=$1
  local start_time=$(date +%s%3N)
  
  local response=$(curl -s -w "\n%{http_code}" -X POST \
    "http://$nlb_endpoint/VLLMDeployment" \
    -H "Content-Type: application/json" \
    -d '{"prompt":"Test","max_tokens":10}' \
    --max-time 10)
  
  local http_code=$(echo "$response" | tail -n1)
  local body=$(echo "$response" | head -n-1)
  local end_time=$(date +%s%3N)
  local duration=$((end_time - start_time))
  
  if [ "$http_code" = "200" ]; then
    echo "SUCCESS: Response in ${duration}ms"
    return 0
  else
    echo "FAIL: HTTP $http_code"
    return 1
  fi
}

# Monitor service availability
monitor_availability() {
  local duration_seconds=$1
  local nlb_endpoint=$2
  local interval=10
  local iterations=$((duration_seconds / interval))
  
  local total_requests=0
  local successful_requests=0
  
  for i in $(seq 1 $iterations); do
    if test_inference "$nlb_endpoint" > /dev/null 2>&1; then
      ((successful_requests++))
    fi
    ((total_requests++))
    sleep $interval
  done
  
  local success_rate=$((successful_requests * 100 / total_requests))
  echo "Success rate: $success_rate% ($successful_requests/$total_requests)"
  
  return $((success_rate >= 90 ? 0 : 1))
}
```

### Test Orchestrator Structure

```bash
#!/bin/bash
set -euo pipefail

# Configuration
NAMESPACE="default"
NLB_ENDPOINT=""
RESULTS_DIR="test-results-$(date +%Y%m%d-%H%M%S)"

# Test functions
test_pre_validation() { ... }
test_single_worker_disruption() { ... }
test_node_drain() { ... }
test_sequential_disruptions() { ... }
test_redis_disruption() { ... }
test_head_disruption() { ... }
test_post_validation() { ... }

# Main execution
main() {
  mkdir -p "$RESULTS_DIR"
  
  echo "=== Zero-Downtime Upgrade Test Suite ==="
  echo "Results directory: $RESULTS_DIR"
  
  # Get NLB endpoint
  NLB_ENDPOINT=$(kubectl get svc ray-serve-nlb -n default \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  
  # Run tests
  test_pre_validation
  test_single_worker_disruption
  test_node_drain
  test_sequential_disruptions
  test_redis_disruption
  test_head_disruption
  test_post_validation
  
  # Generate final report
  generate_report
}

main "$@"
```

## Error Handling

### Failure Scenarios

1. **Pre-validation Failure**
   - Action: Stop test execution immediately
   - Report: List all failed validation checks
   - Exit code: 1

2. **Test Scenario Failure**
   - Action: Continue with remaining tests
   - Report: Mark scenario as failed in summary
   - Exit code: 1 (after all tests complete)

3. **Load Generator Failure**
   - Action: Retry once, then skip scenario
   - Report: Note load generator issue
   - Exit code: 1

4. **Cleanup Failure**
   - Action: Log error and continue
   - Report: List cleanup issues
   - Exit code: 1

### Recovery Procedures

1. **Stuck Pod Deletion**
   - Wait up to 120 seconds
   - Force delete if necessary: `kubectl delete pod --force --grace-period=0`

2. **Node Drain Timeout**
   - Wait up to 600 seconds
   - Skip remaining drain tests if timeout occurs

3. **Service Unavailable**
   - Wait up to 300 seconds for recovery
   - Mark test as failed if service doesn't recover

## Reporting

### Metrics Collected

1. **Per-Test Metrics**
   - Test name and duration
   - Success/failure status
   - Pod counts before/after
   - Service availability percentage
   - Request latency (P50, P95, P99)
   - Error count and types

2. **Summary Metrics**
   - Total tests run
   - Tests passed/failed
   - Overall availability across all tests
   - Aggregate latency statistics
   - Total disruption time

### Report Format

**Console Output**:
```
=== Zero-Downtime Upgrade Test Suite ===
Results directory: test-results-20251019-120000

[1/7] Pre-Test Validation
  ✓ Worker pods: 3/3 running
  ✓ Head pod: 1/1 running
  ✓ Redis pods: 3/3 running
  ✓ PDBs configured correctly
  ✓ NLB healthy
  ✓ Pods distributed across nodes
  ✓ Baseline inference: 1234ms
  Status: PASS

[2/7] Single Worker Disruption
  Starting load generator...
  Deleting worker pod: vllm-serve-worker-abc123
  Monitoring availability (5 minutes)...
  Success rate: 98% (294/300 requests)
  New pod ready in 3m 45s
  Status: PASS

...

=== Test Summary ===
Tests Run: 7
Passed: 6
Failed: 1
Overall Availability: 96.5%
Total Test Duration: 45m 23s
```

**JSON Report** (`test-results-*/summary.json`):
```json
{
  "timestamp": "2025-10-19T12:00:00Z",
  "duration_seconds": 2723,
  "tests": [
    {
      "name": "pre_validation",
      "status": "pass",
      "duration_seconds": 15,
      "checks": {
        "worker_pods": "pass",
        "head_pod": "pass",
        "redis_pods": "pass",
        "pdbs": "pass",
        "nlb": "pass",
        "distribution": "pass",
        "baseline": "pass"
      }
    },
    {
      "name": "single_worker_disruption",
      "status": "pass",
      "duration_seconds": 420,
      "metrics": {
        "total_requests": 300,
        "successful_requests": 294,
        "success_rate": 98.0,
        "latency_p50": 1234,
        "latency_p95": 2456,
        "latency_p99": 3678,
        "recovery_time_seconds": 225
      }
    }
  ],
  "summary": {
    "total_tests": 7,
    "passed": 6,
    "failed": 1,
    "overall_availability": 96.5
  }
}
```

## Testing Strategy

### Manual Testing
- Run test suite on development cluster first
- Verify each scenario individually
- Adjust thresholds based on observed behavior

### Automated Testing
- Integrate into CI/CD pipeline
- Run after infrastructure changes
- Run before production deployments
- Schedule weekly validation runs

### Performance Baseline
- Establish baseline metrics in stable environment
- Compare test results against baseline
- Alert on significant deviations

## Dependencies

### Required Tools
- `kubectl` (v1.28+)
- `jq` (v1.6+)
- `curl` (v7.68+)
- `bash` (v4.0+)

### Kubernetes Resources
- Ray Serve deployment (HA configuration)
- Network Load Balancer
- Sufficient cluster capacity for pod rescheduling

### Permissions
- Read access to pods, services, nodes
- Delete access to pods (for disruption tests)
- Cordon/uncordon access to nodes
- Create/delete access for K6 jobs

## Future Enhancements

1. **Chaos Engineering Integration**
   - Integrate with Chaos Mesh for more sophisticated failure injection
   - Add network latency and partition tests
   - Test resource exhaustion scenarios

2. **Advanced Metrics**
   - Integrate with Prometheus for detailed metrics
   - Track GPU utilization during disruptions
   - Monitor memory and CPU usage patterns

3. **Multi-Region Testing**
   - Test cross-region failover
   - Validate geo-distributed deployments

4. **Automated Remediation**
   - Auto-rollback on test failures
   - Automated issue reporting
   - Integration with incident management systems

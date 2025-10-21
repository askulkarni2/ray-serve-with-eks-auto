# Requirements Document

## Introduction

This document outlines the requirements for a comprehensive test plan to validate zero-downtime upgrades for the Ray Serve vLLM deployment on EKS Auto Mode. The test plan will verify that the high availability configuration maintains service availability during node replacements, pod disruptions, and cluster upgrades.

## Glossary

- **Ray Service**: The Ray Serve deployment running vLLM for LLM inference
- **Worker Pod**: A Ray worker pod running vLLM inference engine with GPU
- **Head Pod**: The Ray head node coordinating the cluster and serving requests
- **PDB**: PodDisruptionBudget - Kubernetes resource that limits voluntary disruptions
- **NLB**: Network Load Balancer - AWS load balancer exposing the service externally
- **Drain**: The process of gracefully removing a node from the cluster
- **Disruption**: Any event that causes a pod to be terminated or rescheduled
- **Availability**: The percentage of time the service successfully responds to requests
- **Latency**: The time taken to process a request from submission to response

## Requirements

### Requirement 1: Pre-Test Environment Validation

**User Story:** As a platform engineer, I want to validate the test environment is properly configured before running upgrade tests, so that test results are reliable and reproducible.

#### Acceptance Criteria

1. WHEN the test begins, THE Test System SHALL verify that exactly 3 Ray worker pods are running and ready
2. WHEN the test begins, THE Test System SHALL verify that exactly 1 Ray head pod is running and ready
3. WHEN the test begins, THE Test System SHALL verify that exactly 3 Redis pods are running and ready
4. WHEN the test begins, THE Test System SHALL verify that all PodDisruptionBudgets exist with correct minAvailable values
5. WHEN the test begins, THE Test System SHALL verify that the Network Load Balancer is provisioned and healthy
6. WHEN the test begins, THE Test System SHALL verify that worker pods are distributed across different nodes
7. WHEN the test begins, THE Test System SHALL execute a baseline inference request and verify successful response within 5 seconds

### Requirement 2: Continuous Load Generation

**User Story:** As a platform engineer, I want to generate continuous load during upgrade tests, so that I can measure the impact of disruptions on real traffic.

#### Acceptance Criteria

1. WHEN the load test starts, THE Load Generator SHALL send inference requests at a rate of 5 requests per second
2. WHILE the load test is running, THE Load Generator SHALL use a pool of 10 concurrent clients
3. WHEN each request is sent, THE Load Generator SHALL record the response time, status code, and timestamp
4. WHEN a request fails, THE Load Generator SHALL record the error type and continue testing
5. WHILE the load test is running, THE Load Generator SHALL output metrics every 10 seconds including success rate and P95 latency

### Requirement 3: Single Worker Pod Disruption Test

**User Story:** As a platform engineer, I want to test that the service remains available when a single worker pod is disrupted, so that I can verify the PDB configuration protects service availability.

#### Acceptance Criteria

1. WHEN a single worker pod is deleted, THE Test System SHALL verify that the deletion completes within 60 seconds
2. WHILE the worker pod is being replaced, THE Service SHALL maintain a success rate above 95 percent
3. WHEN the worker pod is deleted, THE Test System SHALL verify that at least 2 worker pods remain running throughout the disruption
4. WHEN the new worker pod starts, THE Test System SHALL verify it becomes ready within 5 minutes
5. WHEN the disruption test completes, THE Test System SHALL verify that exactly 3 worker pods are running and ready

### Requirement 4: Node Drain Simulation Test

**User Story:** As a platform engineer, I want to simulate a node drain operation, so that I can verify the service handles node replacements gracefully during cluster upgrades.

#### Acceptance Criteria

1. WHEN a node drain is initiated, THE Test System SHALL cordon the node before draining
2. WHEN the node is drained, THE Kubernetes Scheduler SHALL respect the PDB and drain only 1 worker pod at a time
3. WHILE the node is being drained, THE Service SHALL maintain a success rate above 90 percent
4. WHEN a worker pod is evicted, THE Test System SHALL verify the pod terminates within 60 seconds
5. WHEN the drain completes, THE Test System SHALL verify that all worker pods are rescheduled and ready within 10 minutes
6. WHEN the test completes, THE Test System SHALL uncordon the node

### Requirement 5: Multiple Sequential Disruptions Test

**User Story:** As a platform engineer, I want to test multiple sequential disruptions, so that I can verify the service handles rolling upgrades across all nodes.

#### Acceptance Criteria

1. WHEN sequential disruptions begin, THE Test System SHALL disrupt worker pods one at a time with 2 minute intervals
2. WHILE disruptions are occurring, THE Service SHALL maintain a success rate above 90 percent
3. WHEN each disruption occurs, THE Test System SHALL verify that at least 2 worker pods remain running
4. WHEN all disruptions complete, THE Test System SHALL verify that exactly 3 worker pods are running and ready
5. WHEN the test completes, THE Test System SHALL verify that the total downtime is less than 30 seconds

### Requirement 6: Redis Disruption Test

**User Story:** As a platform engineer, I want to test Redis pod disruptions, so that I can verify Ray GCS external storage maintains cluster state during Redis failures.

#### Acceptance Criteria

1. WHEN a Redis pod is deleted, THE Test System SHALL verify that at least 2 Redis pods remain running
2. WHILE a Redis pod is being replaced, THE Ray Cluster SHALL remain operational
3. WHEN the Redis pod is deleted, THE Service SHALL maintain a success rate above 95 percent
4. WHEN the new Redis pod starts, THE Test System SHALL verify it joins the StatefulSet within 2 minutes
5. WHEN the test completes, THE Test System SHALL verify that exactly 3 Redis pods are running and ready

### Requirement 7: Head Pod Disruption Test

**User Story:** As a platform engineer, I want to test head pod disruption, so that I can verify the service recovers when the Ray head node is replaced.

#### Acceptance Criteria

1. WHEN the head pod is deleted, THE Test System SHALL verify that the PDB prevents deletion if it would violate minAvailable
2. WHEN the head pod is replaced, THE Service SHALL experience a temporary outage of less than 2 minutes
3. WHEN the new head pod starts, THE Test System SHALL verify it becomes ready within 3 minutes
4. WHEN the head pod is ready, THE Test System SHALL verify that all worker pods reconnect within 1 minute
5. WHEN the test completes, THE Service SHALL return to normal operation with success rate above 95 percent

### Requirement 8: Metrics Collection and Reporting

**User Story:** As a platform engineer, I want comprehensive metrics collected during tests, so that I can analyze service behavior and identify performance issues.

#### Acceptance Criteria

1. WHILE tests are running, THE Test System SHALL collect request success rate every 10 seconds
2. WHILE tests are running, THE Test System SHALL collect P50, P95, and P99 latency metrics every 10 seconds
3. WHILE tests are running, THE Test System SHALL collect pod status changes with timestamps
4. WHEN each test completes, THE Test System SHALL generate a summary report with total requests, success rate, and latency percentiles
5. WHEN all tests complete, THE Test System SHALL generate a final report comparing results across all test scenarios

### Requirement 9: Automated Test Execution

**User Story:** As a platform engineer, I want to execute all tests automatically with a single command, so that I can easily validate upgrades in CI/CD pipelines.

#### Acceptance Criteria

1. WHEN the test suite is invoked, THE Test System SHALL execute all test scenarios in sequence
2. WHEN a test fails, THE Test System SHALL continue with remaining tests and report all failures at the end
3. WHEN tests complete, THE Test System SHALL exit with code 0 if all tests pass or code 1 if any test fails
4. WHILE tests are running, THE Test System SHALL output progress information to stdout
5. WHEN tests complete, THE Test System SHALL save detailed logs and metrics to a timestamped directory

### Requirement 10: Cleanup and Validation

**User Story:** As a platform engineer, I want the test system to clean up after tests and validate the final state, so that the environment is ready for production use.

#### Acceptance Criteria

1. WHEN all tests complete, THE Test System SHALL verify that exactly 3 worker pods are running and ready
2. WHEN all tests complete, THE Test System SHALL verify that exactly 1 head pod is running and ready
3. WHEN all tests complete, THE Test System SHALL verify that exactly 3 Redis pods are running and ready
4. WHEN all tests complete, THE Test System SHALL execute 10 inference requests and verify 100 percent success rate
5. WHEN cleanup is needed, THE Test System SHALL uncordon any cordoned nodes and remove any test artifacts

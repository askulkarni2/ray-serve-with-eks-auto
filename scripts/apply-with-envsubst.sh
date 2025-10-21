#!/bin/bash
# Helper script to apply Kubernetes manifests with environment variable substitution

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <yaml-file>"
    echo "Example: $0 app/ray-serve-vllm-ha.yaml"
    exit 1
fi

YAML_FILE="$1"

if [ ! -f "$YAML_FILE" ]; then
    echo "Error: File $YAML_FILE not found"
    exit 1
fi

# Get AWS account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Using AWS Account ID: $AWS_ACCOUNT_ID"
echo "Applying $YAML_FILE..."

# Substitute environment variables and apply
envsubst < "$YAML_FILE" | kubectl apply -f -

echo "✅ Applied successfully"

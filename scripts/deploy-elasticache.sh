#!/bin/bash
set -e

echo "🚀 Deploying ElastiCache Redis cluster for Ray..."
echo ""

# Get cluster information
CLUSTER_NAME=$(kubectl config current-context | cut -d'@' -f2 | cut -d'.' -f1)
AWS_REGION=${AWS_REGION:-us-west-2}

echo "📋 Getting cluster network configuration..."

# Get VPC ID from cluster
VPC_ID=$(aws eks describe-cluster \
    --name "$CLUSTER_NAME" \
    --region "$AWS_REGION" \
    --query 'cluster.resourcesVpcConfig.vpcId' \
    --output text)

# Get VPC CIDR
VPC_CIDR=$(aws ec2 describe-vpcs \
    --vpc-ids "$VPC_ID" \
    --region "$AWS_REGION" \
    --query 'Vpcs[0].CidrBlock' \
    --output text)

# Get subnet IDs from cluster
SUBNET_IDS=$(aws eks describe-cluster \
    --name "$CLUSTER_NAME" \
    --region "$AWS_REGION" \
    --query 'cluster.resourcesVpcConfig.subnetIds' \
    --output text)

# Convert to array
SUBNET_ARRAY=($SUBNET_IDS)

if [ ${#SUBNET_ARRAY[@]} -lt 2 ]; then
    echo "❌ Error: Need at least 2 subnets for ElastiCache Multi-AZ"
    exit 1
fi

SUBNET_ID_1=${SUBNET_ARRAY[0]}
SUBNET_ID_2=${SUBNET_ARRAY[1]}
SUBNET_ID_3=${SUBNET_ARRAY[2]:-$SUBNET_ID_1}

echo "   VPC ID: $VPC_ID"
echo "   VPC CIDR: $VPC_CIDR"
echo "   Subnet 1: $SUBNET_ID_1"
echo "   Subnet 2: $SUBNET_ID_2"
echo "   Subnet 3: $SUBNET_ID_3"
echo ""

# Create Security Group via AWS CLI
echo "🔒 Creating Security Group for ElastiCache..."
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name ray-elasticache-redis-sg \
    --description "Security group for Ray ElastiCache Redis cluster" \
    --vpc-id "$VPC_ID" \
    --region "$AWS_REGION" \
    --query 'GroupId' \
    --output text 2>/dev/null || \
    aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=ray-elasticache-redis-sg" "Name=vpc-id,Values=$VPC_ID" \
        --region "$AWS_REGION" \
        --query 'SecurityGroups[0].GroupId' \
        --output text)

echo "   Security Group ID: $SECURITY_GROUP_ID"

# Add ingress rule for Redis
echo "🔐 Adding ingress rule for Redis..."
aws ec2 authorize-security-group-ingress \
    --group-id "$SECURITY_GROUP_ID" \
    --protocol tcp \
    --port 6379 \
    --cidr "$VPC_CIDR" \
    --region "$AWS_REGION" 2>/dev/null || echo "   Rule already exists"

# Tag the security group
aws ec2 create-tags \
    --resources "$SECURITY_GROUP_ID" \
    --tags Key=Name,Value=ray-elasticache-redis-sg Key=ManagedBy,Value=ACK \
    --region "$AWS_REGION"

# Create temporary file with substituted values
TEMP_FILE=$(mktemp)
export VPC_ID VPC_CIDR SUBNET_ID_1 SUBNET_ID_2 SUBNET_ID_3 SECURITY_GROUP_ID

echo "📝 Preparing ElastiCache configuration..."
envsubst < app/elasticache-redis.yaml > "$TEMP_FILE"

# Deploy Cache Subnet Group
echo "🌐 Creating Cache Subnet Group..."
cat <<EOF | kubectl apply -f -
apiVersion: elasticache.services.k8s.aws/v1alpha1
kind: CacheSubnetGroup
metadata:
  name: ray-elasticache-subnet-group
  namespace: default
spec:
  cacheSubnetGroupName: ray-elasticache-subnet-group
  cacheSubnetGroupDescription: Subnet group for Ray ElastiCache Redis cluster
  subnetIDs:
    - $SUBNET_ID_1
    - $SUBNET_ID_2
    - $SUBNET_ID_3
  tags:
    - key: Name
      value: ray-elasticache-subnet-group
    - key: ManagedBy
      value: ACK
EOF

# Wait for subnet group to be ready
echo "⏳ Waiting for Cache Subnet Group to be ready..."
sleep 15

# Deploy Replication Group
echo "🗄️  Creating ElastiCache Replication Group..."
echo "   This will take 10-15 minutes..."
cat <<EOF | kubectl apply -f -
apiVersion: elasticache.services.k8s.aws/v1alpha1
kind: ReplicationGroup
metadata:
  name: ray-redis-cluster
  namespace: default
spec:
  replicationGroupID: ray-redis-cluster
  description: Redis cluster for Ray GCS fault tolerance
  engine: redis
  engineVersion: "7.1"
  cacheNodeType: cache.r7g.large
  replicasPerNodeGroup: 2
  automaticFailoverEnabled: true
  multiAZEnabled: true
  cacheSubnetGroupName: ray-elasticache-subnet-group
  securityGroupIDs:
    - $SECURITY_GROUP_ID
  atRestEncryptionEnabled: true
  transitEncryptionEnabled: false
  port: 6379
  snapshotRetentionLimit: 5
  snapshotWindow: "03:00-05:00"
  preferredMaintenanceWindow: "sun:05:00-sun:07:00"
  tags:
    - key: Name
      value: ray-redis-cluster
    - key: ManagedBy
      value: ACK
    - key: Purpose
      value: RayGCS
EOF

rm -f "$TEMP_FILE"

echo ""
echo "⏳ Waiting for ElastiCache cluster to be available..."
echo "   You can monitor progress with:"
echo "   kubectl get replicationgroup ray-redis-cluster -n default -w"
echo ""

# Wait for cluster to be ready (with timeout)
TIMEOUT=900  # 15 minutes
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    STATUS=$(kubectl get replicationgroup ray-redis-cluster -n default -o jsonpath='{.status.status}' 2>/dev/null || echo "creating")
    
    if [ "$STATUS" = "available" ]; then
        echo ""
        echo "✅ ElastiCache cluster is ready!"
        break
    fi
    
    echo "   Status: $STATUS (${ELAPSED}s elapsed)"
    sleep 30
    ELAPSED=$((ELAPSED + 30))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo ""
    echo "⚠️  Timeout waiting for cluster. Check status with:"
    echo "   kubectl describe replicationgroup ray-redis-cluster -n default"
    exit 1
fi

# Get cluster endpoint
echo ""
echo "📡 Getting cluster endpoint..."
REDIS_ENDPOINT=$(kubectl get replicationgroup ray-redis-cluster -n default -o jsonpath='{.status.configurationEndpoint.address}')
REDIS_PORT=$(kubectl get replicationgroup ray-redis-cluster -n default -o jsonpath='{.status.configurationEndpoint.port}')

echo ""
echo "✅ ElastiCache Redis cluster deployed successfully!"
echo ""
echo "📋 Cluster Details:"
echo "   Endpoint: $REDIS_ENDPOINT"
echo "   Port: $REDIS_PORT"
echo "   Full Address: $REDIS_ENDPOINT:$REDIS_PORT"
echo ""
echo "🔄 Next steps:"
echo "   1. Update Ray Service to use this endpoint"
echo "   2. Run: ./scripts/update-ray-redis-endpoint.sh"

#!/bin/bash
set -e

echo "🧹 Cleaning up ElastiCache resources..."
echo ""

REGION=${AWS_REGION:-us-west-2}

# Check if replication group still exists
echo "📋 Checking ElastiCache cluster status..."
STATUS=$(aws elasticache describe-replication-groups \
    --replication-group-id ray-redis-cluster \
    --region "$REGION" \
    --query 'ReplicationGroups[0].Status' \
    --output text 2>/dev/null || echo "not-found")

if [ "$STATUS" != "not-found" ]; then
    echo "   Status: $STATUS"
    
    if [ "$STATUS" != "deleting" ]; then
        echo "🗑️  Deleting ElastiCache replication group..."
        aws elasticache delete-replication-group \
            --replication-group-id ray-redis-cluster \
            --region "$REGION"
    fi
    
    echo "⏳ Waiting for ElastiCache cluster to be deleted (this may take 5-10 minutes)..."
    while true; do
        STATUS=$(aws elasticache describe-replication-groups \
            --replication-group-id ray-redis-cluster \
            --region "$REGION" \
            --query 'ReplicationGroups[0].Status' \
            --output text 2>/dev/null || echo "not-found")
        
        if [ "$STATUS" = "not-found" ]; then
            echo "   ✅ ElastiCache cluster deleted"
            break
        fi
        
        echo "   Status: $STATUS"
        sleep 30
    done
else
    echo "   ✅ ElastiCache cluster already deleted"
fi

# Delete subnet group
echo ""
echo "🗑️  Deleting cache subnet group..."
aws elasticache delete-cache-subnet-group \
    --cache-subnet-group-name ray-elasticache-subnet-group \
    --region "$REGION" 2>/dev/null && echo "   ✅ Subnet group deleted" || echo "   ℹ️  Subnet group not found or already deleted"

# Get security group ID
echo ""
echo "🔍 Finding security group..."
SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=ray-elasticache-redis-sg" \
    --region "$REGION" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || echo "None")

if [ "$SG_ID" != "None" ] && [ -n "$SG_ID" ]; then
    echo "   Found: $SG_ID"
    echo "🗑️  Deleting security group..."
    aws ec2 delete-security-group \
        --group-id "$SG_ID" \
        --region "$REGION" 2>/dev/null && echo "   ✅ Security group deleted" || echo "   ⚠️  Could not delete security group (may have dependencies)"
else
    echo "   ℹ️  Security group not found or already deleted"
fi

echo ""
echo "✅ ElastiCache cleanup complete!"
echo ""
echo "📊 Remaining resources check:"
echo ""

# Check for any remaining ElastiCache resources
REMAINING=$(aws elasticache describe-replication-groups \
    --region "$REGION" \
    --query 'ReplicationGroups[?contains(ReplicationGroupId, `ray`)].ReplicationGroupId' \
    --output text 2>/dev/null || echo "")

if [ -z "$REMAINING" ]; then
    echo "   ✅ No ElastiCache clusters found"
else
    echo "   ⚠️  Found clusters: $REMAINING"
fi

# Check for subnet groups
SUBNET_GROUPS=$(aws elasticache describe-cache-subnet-groups \
    --region "$REGION" \
    --query 'CacheSubnetGroups[?contains(CacheSubnetGroupName, `ray`)].CacheSubnetGroupName' \
    --output text 2>/dev/null || echo "")

if [ -z "$SUBNET_GROUPS" ]; then
    echo "   ✅ No cache subnet groups found"
else
    echo "   ⚠️  Found subnet groups: $SUBNET_GROUPS"
fi

# Check for security groups
SECURITY_GROUPS=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=*ray*elasticache*" \
    --region "$REGION" \
    --query 'SecurityGroups[].GroupId' \
    --output text 2>/dev/null || echo "")

if [ -z "$SECURITY_GROUPS" ]; then
    echo "   ✅ No security groups found"
else
    echo "   ⚠️  Found security groups: $SECURITY_GROUPS"
fi

echo ""
echo "🎉 All done!"

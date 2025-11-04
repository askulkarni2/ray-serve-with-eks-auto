#!/bin/bash
set -e

echo "🚀 Installing ACK ElastiCache Controller..."
echo ""

# Get AWS account ID and region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${AWS_REGION:-us-west-2}
CLUSTER_NAME=$(kubectl config current-context | cut -d'@' -f2 | cut -d'.' -f1)

echo "📋 Configuration:"
echo "   AWS Account: $AWS_ACCOUNT_ID"
echo "   Region: $AWS_REGION"
echo "   Cluster: $CLUSTER_NAME"
echo ""

# Create namespace for ACK
echo "📦 Creating ack-system namespace..."
kubectl create namespace ack-system --dry-run=client -o yaml | kubectl apply -f -

# Note: ACK charts are in OCI registry, no need to add repo
echo "📚 Using ACK charts from public.ecr.aws..."

# Create IAM policy for ElastiCache controller
echo "🔐 Creating IAM policy for ElastiCache controller..."
cat > /tmp/ack-elasticache-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "elasticache:CreateReplicationGroup",
                "elasticache:DeleteReplicationGroup",
                "elasticache:DescribeReplicationGroups",
                "elasticache:ModifyReplicationGroup",
                "elasticache:CreateCacheSubnetGroup",
                "elasticache:DeleteCacheSubnetGroup",
                "elasticache:DescribeCacheSubnetGroups",
                "elasticache:CreateCacheParameterGroup",
                "elasticache:DeleteCacheParameterGroup",
                "elasticache:DescribeCacheParameterGroups",
                "elasticache:ModifyCacheParameterGroup",
                "elasticache:DescribeCacheParameters",
                "elasticache:AddTagsToResource",
                "elasticache:ListTagsForResource",
                "elasticache:RemoveTagsFromResource",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSubnets",
                "ec2:DescribeVpcs",
                "ec2:CreateSecurityGroup",
                "ec2:DeleteSecurityGroup",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:CreateTags"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# Create or update IAM policy
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/ACKElastiCacheControllerPolicy"
if aws iam get-policy --policy-arn "$POLICY_ARN" 2>/dev/null; then
    echo "   Policy already exists, creating new version..."
    aws iam create-policy-version \
        --policy-arn "$POLICY_ARN" \
        --policy-document file:///tmp/ack-elasticache-policy.json \
        --set-as-default
else
    echo "   Creating new policy..."
    aws iam create-policy \
        --policy-name ACKElastiCacheControllerPolicy \
        --policy-document file:///tmp/ack-elasticache-policy.json
fi

# Create IAM role for Pod Identity
echo "🔑 Creating IAM role for Pod Identity..."
ROLE_NAME="${CLUSTER_NAME}-ack-elasticache-controller"

# Create trust policy for Pod Identity
cat > /tmp/trust-policy.json <<TRUST_EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "pods.eks.amazonaws.com"
            },
            "Action": [
                "sts:AssumeRole",
                "sts:TagSession"
            ]
        }
    ]
}
TRUST_EOF

# Create IAM role
if aws iam get-role --role-name "$ROLE_NAME" 2>/dev/null; then
    echo "   Role already exists, updating trust policy..."
    aws iam update-assume-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-document file:///tmp/trust-policy.json
else
    echo "   Creating new role..."
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document file:///tmp/trust-policy.json \
        --description "Role for ACK ElastiCache Controller with Pod Identity"
fi

# Attach policy to role
echo "   Attaching policy to role..."
aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn "$POLICY_ARN"

# Create service account
echo "📝 Creating service account..."
kubectl create serviceaccount ack-elasticache-controller -n ack-system --dry-run=client -o yaml | kubectl apply -f -

# Create Pod Identity Association
echo "🔗 Creating Pod Identity Association..."
ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"

# Check if association already exists
EXISTING_ASSOC=$(aws eks list-pod-identity-associations \
    --cluster-name "$CLUSTER_NAME" \
    --namespace ack-system \
    --service-account ack-elasticache-controller \
    --region "$AWS_REGION" \
    --query 'associations[0].associationArn' \
    --output text 2>/dev/null || echo "None")

if [ "$EXISTING_ASSOC" != "None" ] && [ -n "$EXISTING_ASSOC" ]; then
    echo "   Deleting existing Pod Identity Association..."
    aws eks delete-pod-identity-association \
        --cluster-name "$CLUSTER_NAME" \
        --association-id "${EXISTING_ASSOC##*/}" \
        --region "$AWS_REGION"
    sleep 5
fi

echo "   Creating new Pod Identity Association..."
aws eks create-pod-identity-association \
    --cluster-name "$CLUSTER_NAME" \
    --namespace ack-system \
    --service-account ack-elasticache-controller \
    --role-arn "$ROLE_ARN" \
    --region "$AWS_REGION"

# Install ACK ElastiCache controller
echo "📦 Installing ACK ElastiCache controller..."
helm install ack-elasticache-controller \
    oci://public.ecr.aws/aws-controllers-k8s/elasticache-chart \
    --version 1.2.3 \
    --namespace ack-system \
    --set aws.region="$AWS_REGION" \
    --set serviceAccount.create=false \
    --set serviceAccount.name=ack-elasticache-controller

echo ""
echo "⏳ Waiting for controller to be ready..."
sleep 10
kubectl wait --for=condition=available --timeout=300s \
    deployment -l app.kubernetes.io/name=elasticache-chart \
    -n ack-system

echo ""
echo "✅ ACK ElastiCache Controller installed successfully!"
echo ""
echo "🔍 Verifying installation..."
kubectl get pods -n ack-system
echo ""
kubectl get crd | grep elasticache

echo ""
echo "✅ Ready to deploy ElastiCache clusters!"

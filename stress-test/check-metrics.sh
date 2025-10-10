#!/bin/bash

echo "Checking Container Insights setup..."

# Check if CloudWatch agent is running
kubectl get pods -n amazon-cloudwatch

# Check if metrics are being collected
kubectl top nodes
kubectl top pods

echo ""
echo "If 'kubectl top' shows data, Container Insights is working."
echo "Wait 5-10 minutes for CloudWatch alarms to get sufficient data."
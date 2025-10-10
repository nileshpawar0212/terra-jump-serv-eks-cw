#!/bin/bash

echo "Starting CloudWatch alarm stress tests..."

# Apply stress tests
kubectl apply -f cpu-stress.yaml
kubectl apply -f memory-stress.yaml  
kubectl apply -f restart-test.yaml

echo "Stress tests deployed. Monitor CloudWatch alarms for 5-10 minutes."
echo "Expected alarms:"
echo "- CPU utilization > 50%"
echo "- Memory utilization > 50%" 
echo "- Pod restarts > 5"

echo ""
echo "To check pod status:"
echo "kubectl get pods"
echo ""
echo "To clean up:"
echo "kubectl delete -f ."
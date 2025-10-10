# terraform-eks-jump-server

Create S3 bucket 1st

aws s3api create-bucket --bucket terra-jenkins-eks1 --region us-east-1


# Test Components

cpu-stress.yaml - High CPU load (triggers >50% CPU alarm)

memory-stress.yaml - High memory usage (triggers >50% memory alarm)

restart-test.yaml - Failing pods (triggers >5 restarts alarm)

To run tests:

Connect to EKS cluster via jump server

Run: kubectl apply -f stress-test/

Monitor CloudWatch alarms for 5-10 minutes

Check email for SNS notifications

Expected alerts:

Node CPU > 50%

Node memory > 50%

Pod restarts > 5

The tests will automatically trigger your CloudWatch alarms and send notifications to techieegale@gmail.com.

# Delete additional resources and access if attached to additional to cluster
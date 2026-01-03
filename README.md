NGINX Ingress Controller Deployment

A complete, production-ready NGINX Ingress Controller deployment for Kubernetes featuring DDoS protection, rate limiting, security hardening, and monitoring.

Maintained by Abdelrhman H. Musaa
Version 1.0.0 — Last Updated: January 2026

📋 Overview

This repository provides an end-to-end NGINX Ingress Controller setup designed for reliability, performance, and security.
It includes:

NGINX Ingress Controller as a DaemonSet

Built-in rate limiting and connection limiting

DDoS mitigation

Monitoring and health endpoints

A test application for validation

RBAC, TLS, and security best practices

📑 Table of Contents

Quick Start

File Structure

Configuration Details

Performance Features

Monitoring

Troubleshooting

Updating Configuration

Scaling

Security Notes

Maintenance

Success Criteria

Contributing

References

Disclaimer

🚀 Quick Start
1. Deploy Everything
kubectl apply -f final-ingress-setup.yaml

2. Wait for Deployment
kubectl get pods -n ingress-nginx -w
kubectl get pods -n default -l app=test-app

3. Test the Setup
# Health check
curl http://10.10.0.204/healthz

# Main application
curl http://10.10.0.204/

# API endpoint
curl http://10.10.0.204/api

# NGINX status
curl http://10.10.0.204/nginx_status

📁 File Structure
~/AMusaa/
├── final-ingress-setup.yaml    # Complete deployment configuration
└── test-ingress.sh             # Validation and health test script

🔧 Configuration Details
1. NGINX Ingress Controller

Type: DaemonSet

Networking: hostNetwork: true

Ports: 80 (HTTP), 443 (HTTPS)

Features

Rate limiting (DDoS protection)

Health endpoint (/healthz)

Monitoring endpoint (/nginx_status)

SSL/TLS termination

Real IP handling

2. Test Application

Type: Deployment

Replicas: 2

Image: nginx:alpine

Service: ClusterIP

Endpoints

/

/api

/auth

/healthz

3. RBAC Permissions

Full Ingress management permissions

EndpointSlice and Lease access

Service discovery enabled

⚡ Performance Features
Rate Limiting (DDoS Protection)
# Authentication endpoints
5 requests/second per IP

# API endpoints
100 requests/minute per IP

# General traffic
10 requests/second per IP

Connection Limits

Max concurrent connections: 100 per IP

Worker connections: 4096

Target latency: ≤ 150ms

Security Headers
X-Content-Type-Options: nosniff
X-Frame-Options: SAMEORIGIN
X-XSS-Protection: "1; mode=block"
X-DDOS-Protection: "enabled"

📊 Monitoring
Health Checks
curl http://10.10.0.204/healthz
# Expected output: healthy

NGINX Status
curl http://10.10.0.204/nginx_status


Includes:

Active connections

Accepted requests

Handled requests

Kubernetes Monitoring
# Ingress controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app=nginx-ingress-controller

# Test application
kubectl get pods -l app=test-app
kubectl logs -l app=test-app

# Services and endpoints
kubectl get svc,ep -n default

🛠️ Troubleshooting
1. Port 80 Not Accessible
netstat -tlnp | grep :80

# Try alternative ports
curl http://10.10.0.204:8080/healthz
curl http://10.10.0.204:30080/healthz

2. 503 Service Unavailable
kubectl get endpoints test-app-service
kubectl get pods -l app=test-app --show-labels
kubectl logs -n ingress-nginx -l app=nginx-ingress-controller --tail=20

3. RBAC Permission Errors
kubectl describe clusterrole nginx-ingress-clusterrole
kubectl describe clusterrolebinding nginx-ingress-clusterrole-nisa-binding

Quick Fix Commands
# Restart Ingress controller
kubectl delete pods -n ingress-nginx -l app=nginx-ingress-controller

# Recreate test application
kubectl delete deployment test-app
kubectl apply -f final-ingress-setup.yaml

# Verify configuration
kubectl describe configmap ingress-nginx-controller -n ingress-nginx

🔄 Update Configuration
Modify Rate Limits

Edit the http-snippet in the ConfigMap:

http-snippet: |
  limit_req_zone $binary_remote_addr zone=auth_limit:10m rate=10r/s;
  limit_req_zone $binary_remote_addr zone=api_limit:10m rate=200r/m;

Add Custom Routes
paths:
- path: /new-endpoint
  pathType: Prefix
  backend:
    service:
      name: your-service
      port:
        number: 80

📈 Scaling
Horizontal Pod Autoscaler (Example)
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: test-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: test-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70

Resource Limits
resources:
  requests:
    cpu: "100m"
    memory: "90Mi"
  limits:
    cpu: "1000m"
    memory: "1024Mi"

🔐 Security Notes
SSL/TLS Configuration

This setup uses self-signed certificates for testing.

Generate Certificates
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=your-domain.com"

Create Kubernetes Secret
kubectl create secret tls your-tls-secret \
  --key tls.key --cert tls.crt \
  -n ingress-nginx

Update Ingress Controller
args:
  - --default-ssl-certificate=ingress-nginx/your-tls-secret

Network Policies
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ingress-allow
  namespace: ingress-nginx
spec:
  podSelector:
    matchLabels:
      app: nginx-ingress-controller
  policyTypes:
  - Ingress
  ingress:
  - ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
    from:
    - ipBlock:
        cidr: 0.0.0.0/0

📝 Maintenance
Regular Checks
./test-ingress.sh
kubectl logs -n ingress-nginx -l app=nginx-ingress-controller --since=1h
kubectl top pods -n ingress-nginx
kubectl top pods -n default

Backup Configuration
kubectl get configmap ingress-nginx-controller -n ingress-nginx -o yaml > backup-config.yaml
kubectl get ingress test-ingress -n default -o yaml > backup-ingress.yaml

🎯 Success Criteria

The deployment is successful when:

✅ All pods are Running

✅ /healthz returns healthy

✅ Application serves content correctly

✅ Rate limiting is enforced

✅ /nginx_status is accessible (whitelisted IPs)

✅ No errors in controller logs

🤝 Contributing

To customize or extend this setup:

Fork the repository

Modify configurations as needed

Test thoroughly in staging

Deploy to production

📚 References

NGINX Ingress Controller Documentation

Kubernetes Ingress Documentation

NGINX Rate Limiting

⚠️ Disclaimer

This configuration is intended for:

Testing and learning environments

Internal networks with IP whitelisting

Kubernetes Ingress experimentation

For production use:

Replace self-signed certificates

Apply strict network policies

Enable monitoring and alerting

Perform load and security testing

Review all security settings carefully

NGINX Ingress Controller Deployment
📋 Overview
A complete, production-ready NGINX Ingress Controller deployment for Kubernetes with DDOS protection, rate limiting, and monitoring capabilities.

🚀 Quick Start
1. Deploy Everything
bash
# Apply the complete configuration
kubectl apply -f final-ingress-setup.yaml
2. Wait for Deployment
bash
# Check deployment status
kubectl get pods -n ingress-nginx -w
kubectl get pods -n default -l app=test-app
3. Test the Setup
bash
# Test health endpoint
curl http://10.10.0.204/healthz

# Test main application
curl http://10.10.0.204/

# Test API endpoint
curl http://10.10.0.204/api

# Test NGINX status
curl http://10.10.0.204/nginx_status
📁 File Structure
text
~/AMusaa/
├── final-ingress-setup.yaml    # Complete deployment configuration
└── test-ingress.sh            # Test script
🔧 Configuration Details
Main Components
1. NGINX Ingress Controller
Type: DaemonSet with hostNetwork: true

Ports: 80 (HTTP), 443 (HTTPS)

Features:

Rate limiting (DDOS protection)

Health checks (/healthz)

Monitoring (/nginx_status)

SSL/TLS termination

Real IP handling

2. Test Application
Type: Deployment with 2 replicas

Image: nginx:alpine

Service: ClusterIP load balancer

Endpoints: /, /api, /auth, /healthz

3. RBAC Permissions
Full permissions for Ingress management

EndpointSlice and Lease permissions

Service discovery capabilities

⚡ Performance Features
Rate Limiting (DDOS Protection)
nginx
# Authentication endpoints: 5 requests/second per IP
# API endpoints: 100 requests/minute per IP
# General requests: 10 requests/second per IP
Connection Limits
Max concurrent connections: 100 per IP

Worker connections: 4,096

Target latency: ≤150ms

Security Headers
nginx
X-Content-Type-Options: nosniff
X-Frame-Options: SAMEORIGIN
X-XSS-Protection: "1; mode=block"
X-DDOS-Protection: "enabled"
📊 Monitoring
Health Checks
bash
# Manual check
curl http://10.10.0.204/healthz
# Expected: "healthy"
NGINX Status
bash
# Get connection statistics
curl http://10.10.0.204/nginx_status
# Output includes active connections, requests handled, etc.
Kubernetes Monitoring
bash
# Check Ingress controller status
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app=nginx-ingress-controller

# Check test application
kubectl get pods -l app=test-app
kubectl logs -l app=test-app

# Check services and endpoints
kubectl get svc,ep -n default
🛠️ Troubleshooting
Common Issues
1. Port 80 Not Accessible
bash
# Check if port is listening
netstat -tlnp | grep :80

# Try alternative ports
curl http://10.10.0.204:8080/healthz
curl http://10.10.0.204:30080/healthz
2. 503 Service Unavailable
bash
# Check endpoints
kubectl get endpoints test-app-service

# Check pod labels match service selector
kubectl get pods -l app=test-app --show-labels

# Check Ingress controller logs
kubectl logs -n ingress-nginx -l app=nginx-ingress-controller --tail=20
3. RBAC Permission Errors
bash
# Check service account permissions
kubectl describe clusterrole nginx-ingress-clusterrole
kubectl describe clusterrolebinding nginx-ingress-clusterrole-nisa-binding
Quick Fix Commands
bash
# Restart Ingress controller
kubectl delete pods -n ingress-nginx -l app=nginx-ingress-controller

# Recreate test application
kubectl delete deployment test-app
kubectl apply -f final-ingress-setup.yaml

# Check configuration
kubectl describe configmap ingress-nginx-controller -n ingress-nginx
🔄 Update Configuration
Modify Rate Limits
Edit the http-snippet section in the ConfigMap:

yaml
http-snippet: |
  # Adjust rate limits
  limit_req_zone $binary_remote_addr zone=auth_limit:10m rate=10r/s;
  limit_req_zone $binary_remote_addr zone=api_limit:10m rate=200r/m;
Add Custom Routes
Edit the Ingress resource:

yaml
paths:
- path: /new-endpoint
  pathType: Prefix
  backend:
    service:
      name: your-service
      port:
        number: 80
📈 Scaling
Horizontal Pod Autoscaling
yaml
# Example HPA for test application
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
yaml
resources:
  requests:
    cpu: "100m"
    memory: "90Mi"
  limits:
    cpu: "1000m"
    memory: "1024Mi"
🔐 Security Notes
SSL/TLS Configuration
The setup includes a self-signed certificate for testing. For production:

Generate real certificates:

bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=your-domain.com"
Create Kubernetes secret:

bash
kubectl create secret tls your-tls-secret \
  --key tls.key --cert tls.crt \
  -n ingress-nginx
Update DaemonSet args:

yaml
args:
  - --default-ssl-certificate=ingress-nginx/your-tls-secret
Network Policies
yaml
# Restrict access to Ingress controller
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
bash
# Daily health checks
./test-ingress.sh

# Monitor logs
kubectl logs -n ingress-nginx -l app=nginx-ingress-controller --since=1h

# Check resource usage
kubectl top pods -n ingress-nginx
kubectl top pods -n default
Backup Configuration
bash
# Export current configuration
kubectl get configmap ingress-nginx-controller -n ingress-nginx -o yaml > backup-config.yaml
kubectl get ingress test-ingress -n default -o yaml > backup-ingress.yaml
🎯 Success Criteria
The deployment is successful when:

✅ All pods are in Running state

✅ /healthz endpoint returns healthy

✅ Main application serves HTML content

✅ Rate limiting headers are present

✅ NGINX status endpoint is accessible (whitelisted IPs only)

✅ No errors in controller logs

🤝 Contributing
To customize this setup:

Fork the configuration

Modify for your specific needs

Test thoroughly in staging

Deploy to production

📚 References
NGINX Ingress Controller Documentation

Kubernetes Ingress Documentation

NGINX Rate Limiting

⚠️ Disclaimer
This configuration is designed for:

Testing environments with self-signed certificates

Internal networks with IP whitelisting

Learning purposes for Kubernetes Ingress concepts

For production use:

Replace self-signed certificates

Implement proper security policies

Configure monitoring and alerting

Perform load testing

Review all security settings

Maintained by: Abdelrhman H.Musaa
Last Updated: January 2026
Version: 1.0.0

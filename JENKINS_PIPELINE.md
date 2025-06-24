# Jenkins Pipeline Documentation

## Overview

This Jenkins pipeline provides a comprehensive CI/CD solution for the DevApp project, featuring automated testing, security scanning, Docker image building, and deployment to multiple environments.

## Pipeline Features

### 🔧 **Core Capabilities**
- **Multi-language support**: Java (Spring Boot) and TypeScript (Angular)
- **Parallel execution**: Optimized build times with parallel stages
- **Security scanning**: OWASP dependency check and container vulnerability scanning
- **Quality gates**: SonarQube integration with quality gate enforcement
- **Multi-environment deployment**: Staging and production environments
- **Comprehensive notifications**: Slack and email notifications

### 🏗️ **Pipeline Stages**

1. **Checkout & Setup**
   - Clean workspace and checkout source code
   - Set build metadata and display names

2. **Code Quality & Security** (Parallel)
   - Backend tests with JaCoCo coverage
   - Frontend tests with Angular testing framework
   - SonarQube static code analysis

3. **Build Applications** (Parallel)
   - Maven build for Spring Boot services
   - npm build for Angular application
   - Artifact archiving

4. **Security Scanning** (Parallel)
   - OWASP dependency vulnerability check
   - License compliance verification

5. **Docker Build & Security Scan**
   - Multi-stage Docker image builds
   - Trivy container vulnerability scanning
   - Image tagging with version, commit, and latest

6. **Integration Tests**
   - Docker Compose test environment
   - End-to-end integration testing
   - Automatic cleanup

7. **Push Docker Images**
   - Push to container registry (develop/main branches only)
   - Multiple tags for versioning

8. **Deploy to Staging**
   - Automatic deployment on develop branch
   - Infrastructure and application deployment
   - Health checks and rollout verification

9. **Smoke Tests**
   - Basic health checks against staging environment
   - Service endpoint validation

10. **Deploy to Production**
    - Manual approval required
    - Blue-green deployment option
    - Full monitoring stack deployment

## Prerequisites

### Jenkins Configuration

#### Required Plugins
```bash
# Core plugins
kubernetes
docker-workflow
pipeline-stage-view
build-timeout
timestamper

# Testing and quality
junit
jacoco
sonarqube
html-publisher

# Notifications
slack
email-ext

# Security
owasp-dependency-check
```

#### Credentials Setup
Create the following credentials in Jenkins:

| Credential ID | Type | Description |
|---------------|------|-------------|
| `docker-registry-url` | Secret text | Docker registry URL |
| `docker-registry-credentials` | Username/Password | Docker registry credentials |
| `kubeconfig` | Secret file | Kubernetes configuration file |
| `sonar-host-url` | Secret text | SonarQube server URL |
| `sonar-auth-token` | Secret text | SonarQube authentication token |
| `slack-webhook` | Secret text | Slack webhook URL |

### Kubernetes Setup

#### Service Account
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins-agent
  namespace: jenkins
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jenkins-agent
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: jenkins-agent
  namespace: jenkins
```

#### Persistent Volume Claims
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jenkins-maven-cache
  namespace: jenkins
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jenkins-npm-cache
  namespace: jenkins
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

### SonarQube Configuration

#### Quality Gate
Configure a quality gate with the following conditions:
- Coverage: > 80%
- Duplicated Lines: < 3%
- Maintainability Rating: A
- Reliability Rating: A
- Security Rating: A

#### Project Setup
1. Create project with key: `devapp`
2. Generate authentication token
3. Configure webhook: `http://jenkins-url/sonarqube-webhook/`

## Environment Variables

### Required Environment Variables
```bash
# Docker Configuration
DOCKER_REGISTRY=your-registry.com
DOCKER_REPO=devapp

# Kubernetes Configuration
K8S_NAMESPACE=devapp

# SonarQube Configuration
SONAR_PROJECT_KEY=devapp

# Notification Configuration
SLACK_CHANNEL=#devapp-builds
```

## Branch Strategy

### Supported Branches
- **main**: Production deployments with manual approval
- **develop**: Automatic staging deployments
- **feature/***: Build and test only
- **hotfix/***: Build, test, and optional production deployment

### Deployment Flow
```
feature/* → develop → staging → main → production
```

## Notifications

### Slack Notifications
- ✅ Build success with deployment info
- ❌ Build failures with error details
- ⚠️ Unstable builds with quality issues
- 🛑 Aborted builds

### Email Notifications
- Production build failures
- Security vulnerability alerts
- Quality gate failures

## Security Features

### Vulnerability Scanning
- **OWASP Dependency Check**: Scans for known vulnerabilities in dependencies
- **Trivy**: Container image vulnerability scanning
- **License Check**: Ensures license compliance

### Security Thresholds
- CVSS Score: 7.0+ (High/Critical vulnerabilities fail the build)
- Container vulnerabilities: High/Critical severity fails the build

## Monitoring and Observability

### Build Metrics
- Build duration tracking
- Test coverage trends
- Quality gate compliance
- Deployment frequency

### Artifacts
- Test reports (JUnit XML)
- Coverage reports (JaCoCo, LCOV)
- Security scan reports (JSON)
- Docker image manifests

## Troubleshooting

### Common Issues

#### Build Failures
1. Check console output for specific error messages
2. Verify all credentials are properly configured
3. Ensure Kubernetes cluster is accessible
4. Check resource limits and quotas

#### Test Failures
1. Review test reports in build artifacts
2. Check for environment-specific issues
3. Verify test data and dependencies

#### Deployment Issues
1. Check Kubernetes cluster status
2. Verify image registry accessibility
3. Review deployment logs and events

### Debug Commands
```bash
# Check pod status
kubectl get pods -n devapp-staging

# View deployment logs
kubectl logs deployment/user-app -n devapp-staging

# Check service endpoints
kubectl get svc -n devapp-staging

# View build logs
docker logs <container-id>
```

## Customization

### Adding New Services
1. Add build stage for new service
2. Create Dockerfile and Kubernetes manifests
3. Update docker-compose.test.yml
4. Add health checks and tests

### Environment-Specific Configuration
1. Create new namespace in Kubernetes
2. Add environment-specific variables
3. Update deployment conditions
4. Configure monitoring and alerting

## Best Practices

### Performance Optimization
- Use parallel stages where possible
- Cache dependencies (Maven, npm)
- Optimize Docker layer caching
- Use resource limits for containers

### Security Best Practices
- Regular credential rotation
- Principle of least privilege
- Secure secret management
- Regular security scanning

### Maintenance
- Regular plugin updates
- Pipeline script versioning
- Backup Jenkins configuration
- Monitor resource usage

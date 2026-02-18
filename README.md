# DevApp

DevApp is a modern microservice architecture demonstration project featuring two Spring Boot services (`user-app` and `order-app`) and an Angular frontend (`devapp-web`). The services communicate via REST APIs and Kafka messaging, with full containerization support for both development and production deployment.

## 🚀 Quick Start

For the fastest development experience, use the provided devcontainer:

1. **Prerequisites**: Install VS Code with the Dev Containers extension
2. **Open in Container**: Open this project in VS Code and select "Reopen in Container"
3. **Start Development**: The container automatically sets up Java 21, Node.js 24, and all dependencies

> 📖 **Detailed Setup**: See [.devcontainer/README.md](.devcontainer/README.md) for comprehensive development environment documentation.

## Features

### User Service
- CRUD operations for users exposed via `/api/users` REST endpoints.
- Listens to the Kafka topic `order_topic` and notifies users about orders.
- Persists data to PostgreSQL using Spring Data JPA.

### Order Service
- CRUD operations for orders exposed via `/api/orders` REST endpoints.
- Publishes order events to Kafka when a new order is created.
- Caches order lookups using Redis.
- Persists data to PostgreSQL using Spring Data JPA.

### Frontend Application
- **Angular 20** application with standalone components and routing for *Users* and *Orders* pages
- Uses Angular Material for modern UI components and styling
- Angular `HttpClient` for REST API communication with backend services
- Comprehensive testing with Jasmine/Karma unit tests and Cypress E2E tests

### Shared Components
- **devapp-common**: Shared domain entities (`User`, `Order`) and common configuration
- **Development Environment**: Complete devcontainer setup with H2 database for zero-config development
- **Production Ready**: PostgreSQL, Redis, Kafka, and monitoring stack (Prometheus, Grafana, ELK)

### Infrastructure & Deployment
- **Containerization**: Dockerfiles for all services with multi-stage builds
- **Kubernetes**: Production-ready manifests in `k8s/` directory
- **CI/CD**: Jenkins pipeline for automated build, test, and deployment
- **Monitoring**: Integrated observability with metrics, logging, and distributed tracing

## Technology Stack

| Technology | Version | Purpose |
|------------|---------|---------|
| **Java** | 21 (LTS) | Runtime for Spring Boot services |
| **Spring Boot** | 3.5.3 | Microservice framework with web, JPA, Kafka, security starters |
| **Angular** | 20 | Modern frontend framework with standalone components |
| **Node.js** | 24 (LTS) | JavaScript runtime for Angular development |
| **PostgreSQL** | Latest | Production database for both services |
| **H2 Database** | Embedded | Development database (in-memory) |
| **Apache Kafka** | Latest | Asynchronous messaging between services |
| **Redis** | Latest | Caching layer for order service |
| **SpringDoc OpenAPI** | 2.7.0 | API documentation (replaces Springfox) |
| **Angular Material** | 20.x | UI component library |
| **Lombok** | Latest | Reduces Java boilerplate code |
| **Micrometer** | Latest | Application metrics for Prometheus |
| **Logback** | Latest | Structured logging with ELK stack integration |
| **Cypress** | 13.x | End-to-end testing framework |
| **Docker** | Latest | Containerization for all services |
| **Kubernetes** | Latest | Container orchestration |

## 💻 Development

### Using DevContainer (Recommended)

The fastest way to get started:

```bash
# 1. Open in VS Code with Dev Containers extension
# 2. Command Palette (Ctrl+Shift+P) → "Dev Containers: Reopen in Container"
# 3. Wait for automatic setup to complete
# 4. Start services in separate terminals:

# Terminal 1: Angular frontend
cd devapp-web && npm start

# Terminal 2: User service
mvn spring-boot:run -pl user-app

# Terminal 3: Order service
mvn spring-boot:run -pl order-app
```

**Service URLs:**
- Frontend: http://localhost:4200
- User API: http://localhost:8080/api/users
- Order API: http://localhost:8081/api/orders
- Swagger UI: http://localhost:8080/swagger-ui.html
- H2 Console: http://localhost:8080/h2-console

### Manual Setup (Alternative)

If not using devcontainer:

1. **Prerequisites**: Java 21, Node.js 24, Maven 3.9+, Docker
2. **Build**: `mvn clean install`
3. **Start Services**: Use the commands above
4. **Database**: Configure PostgreSQL or use H2 (default)

## 🚀 Production Deployment

### Docker Build & Push

```bash
# Build all services
mvn clean package

# Build Docker images
docker build -t your-registry/user-app:latest user-app
docker build -t your-registry/order-app:latest order-app
docker build -t your-registry/devapp-web:latest devapp-web

# Push to registry
docker push your-registry/user-app:latest
docker push your-registry/order-app:latest
docker push your-registry/devapp-web:latest
```

### Kubernetes Deployment (One Click)

We provide a streamlined deployment script that uses **Ansible** to orchestrate the deployment of infrastructure and applications to Kubernetes.

**Prerequisites:**
- Docker
- kubectl (configured for your cluster)
- Maven (for building backend)
- Ansible (for deployment orchestration)

**Usage:**

```bash
# Deploy everything with default settings
./deployment/deploy.sh

# Deploy specific version to custom namespace
./deployment/deploy.sh -v 1.0.0 -n my-devapp

# Deploy with monitoring stack (ELK + Grafana)
./deployment/deploy.sh -m

# Deploy only (skip build) using custom registry
./deployment/deploy.sh -d -r myregistry.com/devapp
```

**Parameters:**
- `-v <version>`: Application version tag (default: `latest`)
- `-r <registry>`: Docker registry prefix (default: `local`)
- `-n <namespace>`: Kubernetes namespace target (default: `devapp`)
- `-d`: Deploy only mode (skips `mvn package`, `npm build`, and `docker build`)
- `-m`: Include monitoring stack (Elasticsearch, Logstash, Kibana, Prometheus, Grafana)

The script performs the following:
1. Builds Java Backend (Maven)
2. Builds Angular Frontend (npm)
3. Builds Docker Images
4. Invokes Ansible Playbook to:
   - Create Namespace
   - Deploy Infrastructure (Postgres, Kafka, Redis)
   - Deploy Monitoring (optional)
   - Wait for Infrastructure readiness
   - Deploy Application Microservices with correct image tags

### CI/CD Pipeline

The included Jenkins pipeline (`Jenkinsfile`) automates:
- Code compilation and testing
- Docker image building and pushing
- Kubernetes deployment
- Integration testing

## 🧪 Testing

```bash
# Backend tests
mvn test                    # All Java tests
mvn test -pl user-app      # User service tests only
mvn test -pl order-app     # Order service tests only

# Frontend tests
cd devapp-web
npm test                   # Unit tests (Jasmine/Karma)
npm run e2e               # E2E tests (Cypress)

# Integration tests
bash .devcontainer/scripts/test-setup.sh
```

## 📖 API Documentation

### User Service (Port 8080)

#### Endpoints
- `GET /api/users` - Get all users
- `GET /api/users/{id}` - Get user by ID
- `POST /api/users` - Create new user

#### Example Usage
```bash
# Get all users
curl http://localhost:8080/api/users

# Get user by ID
curl http://localhost:8080/api/users/1

# Create new user
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe"}'
```

### Order Service (Port 8081)

#### Endpoints
- `GET /api/orders` - Get all orders
- `GET /api/orders/{id}` - Get order by ID
- `POST /api/orders` - Create new order

#### Example Usage
```bash
# Get all orders
curl http://localhost:8081/api/orders

# Get order by ID
curl http://localhost:8081/api/orders/1

# Create new order
curl -X POST http://localhost:8081/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "productId": 12345,
    "user": {"id": 1, "name": "John Doe"},
    "status": "PENDING"
  }'
```

### Health Checks

Both services provide health check endpoints:
- `GET /actuator/health` - Overall health status
- `GET /actuator/info` - Application information
- `GET /actuator/metrics` - Application metrics
- `GET /actuator/prometheus` - Prometheus metrics

### Authentication

For development, both services use basic authentication:
- Username: `admin`
- Password: `password`

**Note**: API endpoints (`/api/**`) are publicly accessible for development convenience.

## 📚 Additional Resources

- **Development Environment**: [.devcontainer/README.md](.devcontainer/README.md)
- **API Documentation**: Available at `/swagger-ui.html` when services are running
- **Monitoring**: Grafana dashboards and Prometheus metrics
- **Logging**: Centralized logging via ELK stack


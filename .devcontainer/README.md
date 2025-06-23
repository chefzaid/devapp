# DevApp Development Container

This devcontainer provides a complete development environment for the DevApp project, supporting both Angular 20 frontend and Spring Boot 3.4.1 backend development without any additional configuration.

Built on Microsoft's Java devcontainer base image with Ubuntu and pre-configured development tools.

## 🚀 Quick Start

1. **Open in VS Code**: Open this project in VS Code with the Dev Containers extension installed
2. **Reopen in Container**: When prompted, click "Reopen in Container" or use `Ctrl+Shift+P` → "Dev Containers: Reopen in Container"
3. **Wait for Setup**: The container will build and install all dependencies automatically
4. **Start Development**: Use the provided scripts to start services

## 🛠️ What's Included

### Development Tools
- **Java 21** - Latest LTS version for Spring Boot 3.4.1
- **Maven 3.9.x** - Build tool for Java projects
- **Node.js 24.x** - LTS version for Angular 20
- **Angular CLI 20** - Command line interface for Angular
- **TypeScript** - Latest version
- **Git** - Version control

### VS Code Extensions
- Microsoft Java Extension Pack (Spring Boot Tools)
- Angular Language Service
- TypeScript support
- Prettier code formatter
- ESLint
- GitLens
- Docker support

### Services
- **Angular Dev Server** (Port 4200)
- **User App** - Spring Boot service (Port 8080)
- **Order App** - Spring Boot service (Port 8081)
- **H2 Database Console** (Port 8082)
- **Kafka** - Message broker (Port 9092)
- **Zookeeper** - Kafka coordination (Port 2181)
- **PostgreSQL** - Production database (Port 5432)

## 📁 Project Structure

```
devapp/
├── devapp-web/          # Angular 20 frontend
├── user-app/            # Spring Boot user service
├── order-app/           # Spring Boot order service
├── devapp-common/       # Shared domain models
└── .devcontainer/       # Container configuration
    ├── Dockerfile       # Custom development image
    ├── docker-compose.yml
    ├── devcontainer.json
    └── scripts/         # Helper scripts
```

## 🎯 Development Commands

Use these commands to start and manage services:

### Start All Services
```bash
# Start Angular dev server
cd devapp-web && npm start &

# Start User service
mvn spring-boot:run -pl user-app &

# Start Order service
mvn spring-boot:run -pl order-app &
```

### Start Individual Services
```bash
# Angular dev server only
cd devapp-web && npm start

# User service only
mvn spring-boot:run -pl user-app

# Order service only
mvn spring-boot:run -pl order-app
```

### Stop Services
```bash
# Stop all Java processes (Spring Boot services)
pkill -f "spring-boot:run"

# Stop Angular dev server
pkill -f "ng serve"
```

## 🌐 Service URLs

When services are running, they're available at:

- **Angular App**: http://localhost:4200
- **User Service**: http://localhost:8080
  - API: http://localhost:8080/api/users
  - Swagger: http://localhost:8080/swagger-ui.html
- **Order Service**: http://localhost:8081
  - API: http://localhost:8081/api/orders
  - Swagger: http://localhost:8081/swagger-ui.html
- **H2 Console**: http://localhost:8080/h2-console
  - JDBC URL: `jdbc:h2:mem:userdb` or `jdbc:h2:mem:orderdb`
  - Username: `sa`
  - Password: (empty)
- **Kafka**: localhost:9092
  - Topics: `order_topic`
  - Consumer Group: `group_id`
- **Zookeeper**: localhost:2181

## 🗄️ Database Configuration

### Development (Default)
- **Database**: H2 in-memory
- **Profile**: `dev` (automatic)
- **Schema**: Auto-created from centralized scripts
- **Data**: Pre-populated with test data

### Production
- **Database**: PostgreSQL
- **Profile**: Set `SPRING_PROFILES_ACTIVE=prod`
- **Connection**: Configured via environment variables

## � Messaging Architecture

### Kafka Integration
- **Order Service**: Produces messages when orders are created/updated
- **User Service**: Consumes order messages for user notifications
- **Topic**: `order_topic` with 3 partitions
- **Consumer Group**: `group_id`
- **Message Format**: JSON serialized Order objects

### Message Flow
1. Order created/updated in Order Service
2. Order message published to `order_topic`
3. User Service consumes message via `OrderListener`
4. User notification triggered based on order status

## 🔧 Common Commands

### Maven Commands
```bash
mvn clean install                    # Build all modules
mvn test                            # Run all tests
mvn spring-boot:run -pl user-app    # Run user service
mvn spring-boot:run -pl order-app   # Run order service
```

### Angular Commands
```bash
cd devapp-web
npm start                  # Start dev server (same as ng serve --host 0.0.0.0 --port 4200)
npm test                   # Run tests
npm run build              # Build for production
npm run build-prod         # Build for production (optimized)
```

### Kafka Commands
```bash
bash .devcontainer/scripts/kafka-setup.sh setup      # Create topics
bash .devcontainer/scripts/kafka-setup.sh check      # Check connectivity
bash .devcontainer/scripts/kafka-setup.sh test-order # Send test message
bash .devcontainer/scripts/kafka-setup.sh consumer   # Start consumer
bash .devcontainer/scripts/kafka-setup.sh producer   # Start producer
```

## 🐳 Container Features

- **Volume Caching**: Node modules and Maven cache are persisted
- **Port Forwarding**: All service ports automatically forwarded
- **Hot Reload**: Both Angular and Spring Boot support hot reload
- **Database**: H2 embedded database for zero-config development
- **Extensions**: Pre-configured VS Code extensions for full-stack development

## 🔍 Troubleshooting

### Container Won't Start
- Ensure Docker is running
- Check Docker has enough memory (4GB+ recommended)
- Try rebuilding: `Ctrl+Shift+P` → "Dev Containers: Rebuild Container"

### Services Won't Start
- Check ports aren't already in use
- Use `./stop-all.sh` to stop any running services
- Check logs in VS Code terminal

### Database Issues
- H2 console: http://localhost:8080/h2-console
- Use JDBC URL: `jdbc:h2:mem:userdb` or `jdbc:h2:mem:orderdb`
- For PostgreSQL: Ensure container is running with `docker-compose ps`

## 📚 Additional Resources

- [Angular Documentation](https://angular.dev)
- [Spring Boot Documentation](https://spring.io/projects/spring-boot)
- [VS Code Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers)

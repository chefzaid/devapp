# DevApp

DevApp is a demonstration project showing a small microservice architecture. It consists of two Spring Boot services (`user-app` and `order-app`) and an Angular front end (`devapp-web`). The services communicate over REST and Kafka and run on Kubernetes using Docker images. Supporting components such as PostgreSQL, Redis, Kafka, Prometheus, Grafana and the ELK stack are provisioned through Kubernetes manifests.

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

### Front End
- Angular 16 application with routing for *Users* and *Orders* pages.
- Uses the Angular `HttpClient` to call the back end services.
- Cypress end‑to‑end tests are provided under `devapp-web/cypress`.

### Common Module
- Contains the domain entities `User` and `Order` and shared configuration such as Swagger and Logback.

### Infrastructure
- Dockerfiles are present in each module for container builds.
- Kubernetes manifests under `assembly/` deploy the applications along with PostgreSQL, Kafka, Redis, Prometheus, Grafana and the ELK stack.
- A Jenkins pipeline (see `Jenkinsfile`) builds the services, pushes the images and deploys the manifests.

## Technology Stack

| Technology | How & Where Used |
|------------|-----------------|
| **Java 21** | Configured in the parent `pom.xml` for all Spring Boot modules. |
| **Spring Boot 3.3.4** | Provides web, JPA, Kafka, Actuator and Redis starters for the services. |
| **PostgreSQL** | Database for both services (see `.devcontainer/docker-compose.yml` and Kubernetes manifests). |
| **Kafka** | Asynchronous messaging between services. The order service uses a producer (`KafkaProducerConfig`) and the user service uses a consumer (`KafkaConsumerConfig`). |
| **Redis** | Caching layer used in the order service (`RedisConfig`). |
| **Springfox Swagger** | Generates API documentation via `/swagger-ui`. |
| **Lombok** | Reduces boilerplate in entity and service classes. |
| **Micrometer Prometheus** | Exposes application metrics for Prometheus. |
| **Logback & Logstash** | Logging configuration in `logback-spring.xml` forwards logs to the ELK stack. |
| **Angular 16** | Front‑end framework used in `devapp-web`. |
| **Bootstrap** | Basic styling referenced in `devapp-web/src/index.html`. |
| **Cypress** | End‑to‑end tests located in `devapp-web/cypress`. |
| **Docker** | Packaging of each component through Dockerfiles. |
| **Kubernetes** | Deployment manifests stored in `assembly/`. |
| **Jenkins** | CI/CD pipeline defined in `Jenkinsfile`. |

## Local Development

1. Install Docker and Docker Compose.
2. Open the repository in VS Code and reopen in the dev container. The configuration in `.devcontainer` automatically starts PostgreSQL and installs Maven dependencies.
3. From the terminal, build the Java services:
   ```bash
   mvn install
   ```
4. Start the services locally:
   ```bash
   mvn -pl user-app spring-boot:run
   mvn -pl order-app spring-boot:run
   ```
5. In a second terminal run the Angular front end:
   ```bash
   cd devapp-web
   npm install
   npm start
   ```
6. Open <http://localhost:4200> in your browser.

## Production Deployment

1. Package the services and build the Docker images:
   ```bash
   mvn package
   docker build -t your-repo/user-app user-app
   docker build -t your-repo/order-app order-app
   docker build -t your-repo/devapp-web devapp-web
   ```
2. Push the images to your registry.
3. Deploy the Kubernetes manifests contained in the `assembly` directory:
   ```bash
   kubectl apply -f assembly/postgres
   kubectl apply -f assembly/kafka
   kubectl apply -f assembly/grafana
   kubectl apply -f assembly/elk
   kubectl apply -f assembly/user-app-deployment.yaml -f assembly/user-app-service.yaml
   kubectl apply -f assembly/order-app-deployment.yaml -f assembly/order-app-service.yaml
   kubectl apply -f assembly/devapp-web-deployment.yaml -f assembly/devapp-web-service.yaml
   ```
4. The Jenkins pipeline can automate these steps. Adjust Docker registry credentials and run the pipeline to build and deploy automatically.

## Running Tests

- Maven and npm tests can be executed with `mvn test` and `npm test` respectively.
- Note: dependency downloads require internet access.


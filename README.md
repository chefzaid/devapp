Simple set of microservices with the following requirements:

- Based on Java / Spring Boot
- It has an Angular frontend that uses the said backend
- The backend is exposed through REST APIs with Swagger
- The applications are Dockerized and are managed in a cluster through Kubernetes
- The microservices do basic CRUD operation on a Postgres database
- Microservices communicate through Kafka
- Logging is done using ELK stack with ElasticSearch and Logstash and a Kibana dashboard
- Monitoring is done through Prometheus and Grafana
- The delivery pipelines are automated through Jenkins

Optionally, add:
- A Redis store is used for caching
- Authentication is managed by Okta
- Set up Kubernetes and Docker (with private registry)
- Tools (Gitlab, JIRA, Confluence, Nexus/Artifactory)

pipeline {
    agent {
        kubernetes {
            label 'jenkins-agent'
            defaultContainer 'jnlp'
            yaml """
            apiVersion: v1
            kind: Pod
            spec:
              containers:
              - name: maven
                image: maven:3.6.3-jdk-11
                command:
                - cat
                tty: true
              - name: docker
                image: docker:19.03.12
                command:
                - cat
                tty: true
                volumeMounts:
                - mountPath: /var/run/docker.sock
                  name: docker-sock
              volumes:
              - name: docker-sock
                hostPath:
                  path: /var/run/docker.sock
            """
        }
    }

    environment {
        DOCKER_HUB_CREDENTIALS_ID = 'dockerhub-credentials'
        DOCKER_HUB_REPO = 'your-docker-hub-username'
        KUBECTL = '/usr/local/bin/kubectl' // Adjust path as necessary
    }

    stages {
        stage('Build') {
            steps {
                container('maven') {
                    // Build Spring Boot applications
                    sh 'mvn -f order-service/pom.xml clean package'
                    sh 'mvn -f user-service/pom.xml clean package'
                }
            }
        }

        stage('Docker Build & Push') {
            steps {
                container('docker') {
                    // Build and push Docker images
                    script {
                        def orderServiceImage = docker.build("${DOCKER_HUB_REPO}/order-service:${env.BUILD_ID}", 'order-service')
                        def userServiceImage = docker.build("${DOCKER_HUB_REPO}/user-service:${env.BUILD_ID}", 'user-service')

                        docker.withRegistry('https://index.docker.io/v1/', DOCKER_HUB_CREDENTIALS_ID) {
                            orderServiceImage.push()
                            userServiceImage.push()
                        }
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                // Deploy services to Kubernetes
                sh """
                    ${KUBECTL} apply -f k8s/prometheus-configmap.yaml
                    ${KUBECTL} apply -f k8s/prometheus-deployment.yaml
                    ${KUBECTL} apply -f k8s/prometheus-service.yaml
                    ${KUBECTL} apply -f k8s/grafana-deployment.yaml
                    ${KUBECTL} apply -f k8s/grafana-service.yaml
                    ${KUBECTL} apply -f k8s/elasticsearch-deployment.yaml
                    ${KUBECTL} apply -f k8s/elasticsearch-service.yaml
                    ${KUBECTL} apply -f k8s/logstash-configmap.yaml
                    ${KUBECTL} apply -f k8s/logstash-deployment.yaml
                    ${KUBECTL} apply -f k8s/logstash-service.yaml
                    ${KUBECTL} apply -f k8s/kibana-deployment.yaml
                    ${KUBECTL} apply -f k8s/kibana-service.yaml
                    ${KUBECTL} apply -f k8s/zookeeper-deployment.yaml
                    ${KUBECTL} apply -f k8s/zookeeper-service.yaml
                    ${KUBECTL} apply -f k8s/kafka-deployment.yaml
                    ${KUBECTL} apply -f k8s/kafka-service.yaml
                    ${KUBECTL} apply -f k8s/postgres-configmap.yaml
                    ${KUBECTL} apply -f k8s/postgres-secret.yaml
                    ${KUBECTL} apply -f k8s/postgres-persistentvolume.yaml
                    ${KUBECTL} apply -f k8s/postgres-persistentvolumeclaim.yaml
                    ${KUBECTL} apply -f k8s/postgres-deployment.yaml
                    ${KUBECTL} apply -f k8s/postgres-service.yaml
                    ${KUBECTL} apply -f k8s/order-service-deployment.yaml
                    ${KUBECTL} apply -f k8s/user-service-deployment.yaml
                """
            }
        }
    }

    post {
        always {
            // Clean up Docker images
            container('docker') {
                sh 'docker image prune -f'
            }
        }
    }
}

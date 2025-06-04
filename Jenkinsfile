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
                    sh 'mvn -f order-app/pom.xml clean package'
                    sh 'mvn -f user-app/pom.xml clean package'
                }
            }
        }

        stage('Docker Build & Push') {
            steps {
                container('docker') {
                    // Build and push Docker images
                    script {
                        def orderServiceImage = docker.build("${DOCKER_HUB_REPO}/order-app:${env.BUILD_ID}", 'order-app')
                        def userServiceImage = docker.build("${DOCKER_HUB_REPO}/user-app:${env.BUILD_ID}", 'user-app')
                        def webImage = docker.build("${DOCKER_HUB_REPO}/devapp-web:${env.BUILD_ID}", 'devapp-web')

                        docker.withRegistry('https://index.docker.io/v1/', DOCKER_HUB_CREDENTIALS_ID) {
                            orderServiceImage.push()
                            userServiceImage.push()
                            webImage.push()
                        }
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                // Deploy services to Kubernetes
                sh """
                    ${KUBECTL} apply -f assembly/grafana
                    ${KUBECTL} apply -f assembly/elk
                    ${KUBECTL} apply -f assembly/kafka
                    ${KUBECTL} apply -f assembly/postgres
                    ${KUBECTL} apply -f assembly/user-app-deployment.yaml
                    ${KUBECTL} apply -f assembly/user-app-service.yaml
                    ${KUBECTL} apply -f assembly/order-app-deployment.yaml
                    ${KUBECTL} apply -f assembly/order-app-service.yaml
                    ${KUBECTL} apply -f assembly/devapp-web-deployment.yaml
                    ${KUBECTL} apply -f assembly/devapp-web-service.yaml
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

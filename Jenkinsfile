pipeline {
    agent {
        kubernetes {
            label 'devapp-build-agent'
            defaultContainer 'jnlp'
            yaml """
            apiVersion: v1
            kind: Pod
            metadata:
              labels:
                jenkins: agent
                app: devapp-build
            spec:
              serviceAccountName: jenkins-agent
              containers:
              - name: maven
                image: maven:3.9.9-eclipse-temurin-21
                command:
                - cat
                tty: true
                resources:
                  requests:
                    memory: "1Gi"
                    cpu: "500m"
                  limits:
                    memory: "2Gi"
                    cpu: "2000m"
                volumeMounts:
                - name: maven-cache
                  mountPath: /root/.m2/repository
                - name: maven-settings
                  mountPath: /root/.m2/settings.xml
                  subPath: settings.xml
                  readOnly: true
              - name: node
                image: node:24-alpine
                command:
                - cat
                tty: true
                resources:
                  requests:
                    memory: "512Mi"
                    cpu: "250m"
                  limits:
                    memory: "1Gi"
                    cpu: "1000m"
                volumeMounts:
                - name: npm-cache
                  mountPath: /root/.npm
                - name: npm-config
                  mountPath: /root/.npmrc
                  subPath: .npmrc
                  readOnly: true
              - name: docker
                image: docker:27-cli
                command:
                - cat
                tty: true
                resources:
                  requests:
                    memory: "256Mi"
                    cpu: "250m"
                  limits:
                    memory: "512Mi"
                    cpu: "500m"
                volumeMounts:
                - mountPath: /var/run/docker.sock
                  name: docker-sock
                - mountPath: /shared
                  name: shared-images
              - name: k3s-deployer
                image: rancher/kubectl:v1.31.4
                command:
                - cat
                tty: true
                resources:
                  requests:
                    memory: "128Mi"
                    cpu: "100m"
                  limits:
                    memory: "256Mi"
                    cpu: "200m"
                volumeMounts:
                - mountPath: /shared
                  name: shared-images
                - mountPath: /host-bin
                  name: k3s-bin
                  readOnly: true
                - mountPath: /run/k3s
                  name: k3s-containerd
                securityContext:
                  privileged: true
              volumes:
              - name: docker-sock
                hostPath:
                  path: /var/run/docker.sock
              - name: shared-images
                emptyDir: {}
              - name: k3s-bin
                hostPath:
                  path: /usr/local/bin
              - name: k3s-containerd
                hostPath:
                  path: /run/k3s
              - name: maven-cache
                persistentVolumeClaim:
                  claimName: jenkins-maven-cache
              - name: npm-cache
                persistentVolumeClaim:
                  claimName: jenkins-npm-cache
              - name: maven-settings
                configMap:
                  name: jenkins-maven-settings
              - name: npm-config
                configMap:
                  name: jenkins-npm-config
            """
        }
    }

    environment {
        K8S_NAMESPACE = 'devapp'
        SONAR_PROJECT_KEY = 'devapp'
        APP_VERSION = "${env.BUILD_NUMBER}"
        GIT_COMMIT_SHORT = "${env.GIT_COMMIT?.take(7) ?: 'unknown'}"
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 60, unit: 'MINUTES')
        timestamps()
    }

    triggers {
        pollSCM('H/5 * * * *')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    currentBuild.displayName = "#${env.BUILD_NUMBER}-${GIT_COMMIT_SHORT}"
                    currentBuild.description = "Branch: ${env.GIT_BRANCH}"
                }
            }
        }

        stage('Code Quality') {
            parallel {
                stage('Backend Tests') {
                    steps {
                        container('maven') {
                            sh '''
                                mvn clean test -B \
                                    -Dmaven.test.failure.ignore=true \
                                    -Dhttp.proxyHost= -Dhttps.proxyHost=
                            '''
                        }
                    }
                    post {
                        always {
                            junit testResults: '**/target/surefire-reports/*.xml', allowEmptyResults: true
                        }
                    }
                }

                stage('Frontend Lint & Test') {
                    steps {
                        container('node') {
                            dir('devapp-web') {
                                sh '''
                                    npm ci --cache /root/.npm
                                    npm run lint || true
                                    npm run test:ci || true
                                '''
                            }
                        }
                    }
                    post {
                        always {
                            junit testResults: 'devapp-web/test-results.xml', allowEmptyResults: true
                        }
                    }
                }
            }
        }

        stage('Build Applications') {
            parallel {
                stage('Build Backend') {
                    steps {
                        container('maven') {
                            sh '''
                                mvn clean package -B -DskipTests \
                                    -Dmaven.repo.local=/root/.m2/repository \
                                    -Dhttp.proxyHost= -Dhttps.proxyHost=
                            '''
                        }
                    }
                }

                stage('Build Frontend') {
                    steps {
                        container('node') {
                            dir('devapp-web') {
                                sh '''
                                    npm ci --cache /root/.npm
                                    npm run build-prod
                                '''
                            }
                        }
                    }
                }
            }
            post {
                success {
                    archiveArtifacts artifacts: 'user-app/target/*.jar, order-app/target/*.jar', fingerprint: true, allowEmptyArchive: true
                }
            }
        }

        stage('Docker Build') {
            steps {
                container('docker') {
                    sh """
                        IMAGE_TAG="${APP_VERSION}"

                        echo "Building Docker images with tag \${IMAGE_TAG}..."
                        docker build -t devapp/user-app:\${IMAGE_TAG} user-app/
                        docker build -t devapp/order-app:\${IMAGE_TAG} order-app/
                        docker build -t devapp/devapp-web:\${IMAGE_TAG} devapp-web/

                        docker tag devapp/user-app:\${IMAGE_TAG} devapp/user-app:latest
                        docker tag devapp/order-app:\${IMAGE_TAG} devapp/order-app:latest
                        docker tag devapp/devapp-web:\${IMAGE_TAG} devapp/devapp-web:latest

                        echo "Saving images for K3s import..."
                        docker save devapp/user-app:\${IMAGE_TAG} devapp/user-app:latest > /shared/user-app.tar
                        docker save devapp/order-app:\${IMAGE_TAG} devapp/order-app:latest > /shared/order-app.tar
                        docker save devapp/devapp-web:\${IMAGE_TAG} devapp/devapp-web:latest > /shared/devapp-web.tar
                    """
                }
            }
        }

        stage('Import to K3s & Deploy') {
            steps {
                container('k3s-deployer') {
                    sh """
                        echo "Importing images into K3s containerd..."
                        /host-bin/k3s ctr images import /shared/user-app.tar
                        /host-bin/k3s ctr images import /shared/order-app.tar
                        /host-bin/k3s ctr images import /shared/devapp-web.tar

                        echo "Deploying to K3s..."
                        kubectl set image deployment/user-app user-app=devapp/user-app:${APP_VERSION} -n ${K8S_NAMESPACE}
                        kubectl set image deployment/order-app order-app=devapp/order-app:${APP_VERSION} -n ${K8S_NAMESPACE}
                        kubectl set image deployment/devapp-web devapp-web=devapp/devapp-web:${APP_VERSION} -n ${K8S_NAMESPACE}

                        echo "Waiting for rollout..."
                        kubectl rollout status deployment/user-app -n ${K8S_NAMESPACE} --timeout=120s
                        kubectl rollout status deployment/order-app -n ${K8S_NAMESPACE} --timeout=120s
                        kubectl rollout status deployment/devapp-web -n ${K8S_NAMESPACE} --timeout=60s
                    """
                }
            }
        }

        stage('Smoke Tests') {
            steps {
                container('k3s-deployer') {
                    sh """
                        echo "Running smoke tests..."

                        USER_IP=\$(kubectl get svc user-app -n ${K8S_NAMESPACE} -o jsonpath='{.spec.clusterIP}')
                        ORDER_IP=\$(kubectl get svc order-app -n ${K8S_NAMESPACE} -o jsonpath='{.spec.clusterIP}')
                        WEB_IP=\$(kubectl get svc devapp-web -n ${K8S_NAMESPACE} -o jsonpath='{.spec.clusterIP}')

                        wget -q -O /dev/null --timeout=10 "http://\${USER_IP}:8080/actuator/health" || { echo "user-app health check failed"; exit 1; }
                        echo "✅ user-app healthy"

                        wget -q -O /dev/null --timeout=10 "http://\${ORDER_IP}:8081/actuator/health" || { echo "order-app health check failed"; exit 1; }
                        echo "✅ order-app healthy"

                        wget -q -O /dev/null --timeout=10 "http://\${WEB_IP}:80/" || { echo "devapp-web health check failed"; exit 1; }
                        echo "✅ devapp-web healthy"

                        echo "All smoke tests passed!"
                    """
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: '**/*.log', allowEmptyArchive: true
            cleanWs(cleanWhenAborted: true, cleanWhenFailure: true, cleanWhenSuccess: true, cleanWhenUnstable: true, deleteDirs: true)
        }

        success {
            echo "✅ DevApp build #${env.BUILD_NUMBER} succeeded — images deployed to K3s"
        }

        failure {
            echo "❌ DevApp build #${env.BUILD_NUMBER} failed"
        }
    }
}

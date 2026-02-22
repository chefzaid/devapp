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
                    cpu: "1000m"
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
                    cpu: "500m"
                volumeMounts:
                - name: npm-cache
                  mountPath: /root/.npm
                - name: npm-config
                  mountPath: /root/.npmrc
                  subPath: .npmrc
                  readOnly: true
              - name: docker
                image: docker:24.0.7-dind
                command:
                - cat
                tty: true
                resources:
                  requests:
                    memory: "512Mi"
                    cpu: "250m"
                  limits:
                    memory: "1Gi"
                    cpu: "500m"
                volumeMounts:
                - mountPath: /var/run/docker.sock
                  name: docker-sock
                securityContext:
                  privileged: true
              - name: kubectl
                image: bitnami/kubectl:1.31
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
              - name: sonar-scanner
                image: sonarsource/sonar-scanner-cli:5.0
                command:
                - cat
                tty: true
                resources:
                  requests:
                    memory: "256Mi"
                    cpu: "100m"
                  limits:
                    memory: "512Mi"
                    cpu: "200m"
              - name: ansible
                image: cytopia/ansible:latest
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
              volumes:
              - name: docker-sock
                hostPath:
                  path: /var/run/docker.sock
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
        // Docker Registry Configuration
        DOCKER_REGISTRY = credentials('docker-registry-url')
        DOCKER_CREDENTIALS_ID = 'docker-registry-credentials'
        DOCKER_REPO = 'devapp'

        // Kubernetes Configuration
        KUBECONFIG = credentials('kubeconfig')
        K8S_NAMESPACE = 'devapp'

        // SonarQube Configuration
        SONAR_HOST_URL = credentials('sonar-host-url')
        SONAR_AUTH_TOKEN = credentials('sonar-auth-token')
        SONAR_PROJECT_KEY = 'devapp'

        // Application Configuration
        APP_VERSION = "${env.BUILD_NUMBER}"
        GIT_COMMIT_SHORT = "${env.GIT_COMMIT?.take(7) ?: 'unknown'}"

        // Notification Configuration
        SLACK_CHANNEL = '#devapp-builds'
        SLACK_CREDENTIALS_ID = 'slack-webhook'

        // Security Scanning
        TRIVY_CACHE_DIR = '/tmp/trivy-cache'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 60, unit: 'MINUTES')
        skipStagesAfterUnstable()
        parallelsAlwaysFailFast()
        timestamps()
    }

    triggers {
        pollSCM('H/5 * * * *')  // Poll every 5 minutes
        cron('H 2 * * *')       // Daily build at 2 AM
    }

    stages {
        stage('Checkout & Setup') {
            steps {
                script {
                    // Clean workspace
                    cleanWs()

                    // Checkout code
                    checkout scm

                    // Set build display name
                    currentBuild.displayName = "#${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"
                    currentBuild.description = "Branch: ${env.GIT_BRANCH}"
                }
            }
        }

        stage('Code Quality & Security') {
            parallel {
                stage('Backend Tests') {
                    steps {
                        container('maven') {
                            script {
                                try {
                                    sh '''
                                        echo "Running Maven tests..."
                                        mvn clean test -B -Dmaven.test.failure.ignore=true
                                        mvn jacoco:report
                                    '''
                                } catch (Exception e) {
                                    currentBuild.result = 'UNSTABLE'
                                    echo "Backend tests failed: ${e.getMessage()}"
                                }
                            }
                        }
                    }
                    post {
                        always {
                            publishTestResults testResultsPattern: '**/target/surefire-reports/*.xml'
                            publishCoverage adapters: [jacocoAdapter('**/target/site/jacoco/jacoco.xml')], sourceFileResolver: sourceFiles('STORE_LAST_BUILD')
                        }
                    }
                }

                stage('Frontend Tests') {
                    steps {
                        container('node') {
                            dir('devapp-web') {
                                script {
                                    try {
                                        sh '''
                                            echo "Installing dependencies..."
                                            npm ci --cache /root/.npm

                                            echo "Running linting..."
                                            npm run lint

                                            echo "Running unit tests..."
                                            npm run test:ci

                                            echo "Running build test..."
                                            npm run build
                                        '''
                                    } catch (Exception e) {
                                        currentBuild.result = 'UNSTABLE'
                                        echo "Frontend tests failed: ${e.getMessage()}"
                                    }
                                }
                            }
                        }
                    }
                    post {
                        always {
                            publishTestResults testResultsPattern: 'devapp-web/test-results.xml'
                            publishHTML([
                                allowMissing: false,
                                alwaysLinkToLastBuild: true,
                                keepAll: true,
                                reportDir: 'devapp-web/coverage',
                                reportFiles: 'index.html',
                                reportName: 'Frontend Coverage Report'
                            ])
                        }
                    }
                }

                stage('SonarQube Analysis') {
                    steps {
                        container('sonar-scanner') {
                            script {
                                try {
                                    sh '''
                                        sonar-scanner \
                                          -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                                          -Dsonar.sources=. \
                                          -Dsonar.host.url=${SONAR_HOST_URL} \
                                          -Dsonar.login=${SONAR_AUTH_TOKEN} \
                                          -Dsonar.java.binaries=**/target/classes \
                                          -Dsonar.coverage.jacoco.xmlReportPaths=**/target/site/jacoco/jacoco.xml \
                                          -Dsonar.javascript.lcov.reportPaths=devapp-web/coverage/lcov.info
                                    '''
                                } catch (Exception e) {
                                    echo "SonarQube analysis failed: ${e.getMessage()}"
                                }
                            }
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
                                echo "Building Spring Boot applications..."
                                mvn clean package -B -DskipTests \
                                    -Dmaven.repo.local=/root/.m2/repository

                                echo "Copying artifacts..."
                                mkdir -p artifacts/backend
                                cp user-app/target/*.jar artifacts/backend/
                                cp order-app/target/*.jar artifacts/backend/
                            '''
                        }
                    }
                }

                stage('Build Frontend') {
                    steps {
                        container('node') {
                            dir('devapp-web') {
                                sh '''
                                    echo "Building Angular application..."
                                    npm ci --cache /root/.npm
                                    npm run build-prod

                                    echo "Copying artifacts..."
                                    mkdir -p ../artifacts/frontend
                                    cp -r dist/* ../artifacts/frontend/
                                '''
                            }
                        }
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'artifacts/**/*', fingerprint: true
                }
            }
        }

        stage('Security Scanning') {
            parallel {
                stage('Dependency Check') {
                    steps {
                        container('maven') {
                            script {
                                try {
                                    sh '''
                                        mvn org.owasp:dependency-check-maven:check \
                                            -DfailBuildOnCVSS=7 \
                                            -DsuppressionsLocation=dependency-check-suppressions.xml
                                    '''
                                } catch (Exception e) {
                                    currentBuild.result = 'UNSTABLE'
                                    echo "Dependency check found vulnerabilities: ${e.getMessage()}"
                                }
                            }
                        }
                    }
                    post {
                        always {
                            publishHTML([
                                allowMissing: true,
                                alwaysLinkToLastBuild: true,
                                keepAll: true,
                                reportDir: 'target',
                                reportFiles: 'dependency-check-report.html',
                                reportName: 'OWASP Dependency Check Report'
                            ])
                        }
                    }
                }

                stage('License Check') {
                    steps {
                        container('maven') {
                            sh '''
                                mvn license:check
                                mvn license:aggregate-third-party-report
                            '''
                        }
                    }
                }
            }
        }

        stage('Docker Build & Security Scan') {
            steps {
                container('docker') {
                    script {
                        def images = [:]

                        // Build images
                        echo "Building Docker images..."
                        images['user-app'] = docker.build("${DOCKER_REGISTRY}/${DOCKER_REPO}/user-app:${APP_VERSION}", 'user-app')
                        images['order-app'] = docker.build("${DOCKER_REGISTRY}/${DOCKER_REPO}/order-app:${APP_VERSION}", 'order-app')
                        images['devapp-web'] = docker.build("${DOCKER_REGISTRY}/${DOCKER_REPO}/devapp-web:${APP_VERSION}", 'devapp-web')

                        // Security scan with Trivy
                        echo "Scanning images for vulnerabilities..."
                        images.each { name, image ->
                            try {
                                sh """
                                    docker run --rm -v ${TRIVY_CACHE_DIR}:/root/.cache/ \
                                        aquasec/trivy:latest image \
                                        --exit-code 1 \
                                        --severity HIGH,CRITICAL \
                                        --format json \
                                        --output ${name}-trivy-report.json \
                                        ${image.id}
                                """
                            } catch (Exception e) {
                                echo "Security vulnerabilities found in ${name}: ${e.getMessage()}"
                                currentBuild.result = 'UNSTABLE'
                            }
                        }

                        // Tag images
                        images.each { name, image ->
                            image.tag('latest')
                            image.tag("${env.GIT_COMMIT_SHORT}")
                        }

                        env.DOCKER_IMAGES = images.collect { name, image -> "${name}:${image.id}" }.join(',')
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: '*-trivy-report.json', allowEmptyArchive: true
                }
            }
        }

        stage('Integration Tests') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                    changeRequest()
                }
            }
            steps {
                container('docker') {
                    script {
                        try {
                            sh '''
                                echo "Starting integration test environment..."
                                docker-compose -f docker-compose.test.yml up -d

                                echo "Waiting for services to be ready..."
                                sleep 30

                                echo "Running integration tests..."
                                docker-compose -f docker-compose.test.yml exec -T test-runner \
                                    npm run test:integration
                            '''
                        } catch (Exception e) {
                            currentBuild.result = 'UNSTABLE'
                            echo "Integration tests failed: ${e.getMessage()}"
                        } finally {
                            sh 'docker-compose -f docker-compose.test.yml down -v || true'
                        }
                    }
                }
            }
        }

        stage('Push Docker Images') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                }
            }
            steps {
                container('docker') {
                    script {
                        docker.withRegistry("https://${DOCKER_REGISTRY}", DOCKER_CREDENTIALS_ID) {
                            def imageNames = env.DOCKER_IMAGES.split(',')
                            imageNames.each { imageInfo ->
                                def parts = imageInfo.split(':')
                                def imageName = parts[0]
                                def imageId = parts[1]

                                echo "Pushing ${imageName}..."
                                def image = docker.image(imageId)
                                image.push("${APP_VERSION}")
                                image.push('latest')
                                image.push("${env.GIT_COMMIT_SHORT}")
                            }
                        }
                    }
                }
            }
        }

        stage('Deploy to Staging') {
            when {
                branch 'develop'
            }
            environment {
                DEPLOY_ENV = 'staging'
                K8S_NAMESPACE = 'devapp-staging'
            }
            steps {
                container('ansible') {
                    script {
                        try {
                            sh '''
                                echo "Deploying to staging environment using Ansible..."
                                ansible-playbook deployment/ansible/deploy.yml \
                                    -i deployment/ansible/inventory \
                                    -e "namespace=${K8S_NAMESPACE}" \
                                    -e "version=${APP_VERSION}" \
                                    -e "registry=${DOCKER_REGISTRY}/${DOCKER_REPO}" \
                                    -e "monitoring=false"

                                echo "Staging deployment completed successfully!"
                            '''
                        } catch (Exception e) {
                            currentBuild.result = 'FAILURE'
                            error "Staging deployment failed: ${e.getMessage()}"
                        }
                    }
                }
            }
        }

        stage('Smoke Tests') {
            when {
                branch 'develop'
            }
            steps {
                container('kubectl') {
                    script {
                        try {
                            sh '''
                                echo "Running smoke tests against staging..."

                                # Get service endpoints
                                USER_SERVICE_URL=$(kubectl get svc user-app -n ${K8S_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
                                ORDER_SERVICE_URL=$(kubectl get svc order-app -n ${K8S_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
                                WEB_SERVICE_URL=$(kubectl get svc devapp-web -n ${K8S_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

                                # Basic health checks
                                curl -f http://${USER_SERVICE_URL}:8080/actuator/health || exit 1
                                curl -f http://${ORDER_SERVICE_URL}:8081/actuator/health || exit 1
                                curl -f http://${WEB_SERVICE_URL}:80/ || exit 1

                                echo "Smoke tests passed!"
                            '''
                        } catch (Exception e) {
                            currentBuild.result = 'UNSTABLE'
                            echo "Smoke tests failed: ${e.getMessage()}"
                        }
                    }
                }
            }
        }

        stage('Deploy to Production') {
            when {
                allOf {
                    branch 'main'
                    not { changeRequest() }
                }
            }
            environment {
                DEPLOY_ENV = 'production'
                K8S_NAMESPACE = 'devapp-prod'
            }
            steps {
                script {
                    def deployApproved = false
                    try {
                        timeout(time: 10, unit: 'MINUTES') {
                            deployApproved = input(
                                message: 'Deploy to Production?',
                                ok: 'Deploy',
                                parameters: [
                                    choice(
                                        name: 'DEPLOYMENT_STRATEGY',
                                        choices: ['rolling', 'blue-green'],
                                        description: 'Deployment strategy'
                                    )
                                ]
                            )
                        }
                    } catch (Exception e) {
                        echo "Production deployment cancelled or timed out"
                        return
                    }

                    if (deployApproved) {
                        container('ansible') {
                            sh '''
                                echo "Deploying to production environment using Ansible..."
                                ansible-playbook deployment/ansible/deploy.yml \
                                    -i deployment/ansible/inventory \
                                    -e "namespace=${K8S_NAMESPACE}" \
                                    -e "version=${APP_VERSION}" \
                                    -e "registry=${DOCKER_REGISTRY}/${DOCKER_REPO}" \
                                    -e "monitoring=true"

                                echo "Production deployment completed successfully!"
                            '''
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                // Clean up Docker images and containers
                container('docker') {
                    sh '''
                        echo "Cleaning up Docker resources..."
                        docker system prune -f --volumes || true
                        docker image prune -a -f || true
                    '''
                }

                // Archive important artifacts
                archiveArtifacts artifacts: '**/*.log', allowEmptyArchive: true

                // Clean workspace
                cleanWs(
                    cleanWhenAborted: true,
                    cleanWhenFailure: true,
                    cleanWhenNotBuilt: true,
                    cleanWhenSuccess: true,
                    cleanWhenUnstable: true,
                    deleteDirs: true
                )
            }
        }

        success {
            script {
                def message = """
                ✅ *DevApp Build Successful*

                *Build:* ${env.BUILD_NUMBER}
                *Branch:* ${env.GIT_BRANCH}
                *Commit:* ${env.GIT_COMMIT_SHORT}
                *Duration:* ${currentBuild.durationString}

                *Deployed to:* ${env.DEPLOY_ENV ?: 'None'}
                *Docker Images:* ${env.APP_VERSION}

                <${env.BUILD_URL}|View Build Details>
                """

                slackSend(
                    channel: env.SLACK_CHANNEL,
                    color: 'good',
                    message: message,
                    teamDomain: 'your-team',
                    token: env.SLACK_CREDENTIALS_ID
                )
            }
        }

        failure {
            script {
                def message = """
                ❌ *DevApp Build Failed*

                *Build:* ${env.BUILD_NUMBER}
                *Branch:* ${env.GIT_BRANCH}
                *Commit:* ${env.GIT_COMMIT_SHORT}
                *Duration:* ${currentBuild.durationString}
                *Stage:* ${env.STAGE_NAME ?: 'Unknown'}

                <${env.BUILD_URL}|View Build Details>
                <${env.BUILD_URL}console|View Console Output>
                """

                slackSend(
                    channel: env.SLACK_CHANNEL,
                    color: 'danger',
                    message: message,
                    teamDomain: 'your-team',
                    token: env.SLACK_CREDENTIALS_ID
                )

                // Send email notification for production failures
                if (env.GIT_BRANCH == 'main') {
                    emailext(
                        subject: "🚨 DevApp Production Build Failed - #${env.BUILD_NUMBER}",
                        body: """
                        <h2>DevApp Production Build Failed</h2>
                        <p><strong>Build Number:</strong> ${env.BUILD_NUMBER}</p>
                        <p><strong>Branch:</strong> ${env.GIT_BRANCH}</p>
                        <p><strong>Commit:</strong> ${env.GIT_COMMIT_SHORT}</p>
                        <p><strong>Duration:</strong> ${currentBuild.durationString}</p>
                        <p><strong>Failed Stage:</strong> ${env.STAGE_NAME ?: 'Unknown'}</p>

                        <p><a href="${env.BUILD_URL}">View Build Details</a></p>
                        <p><a href="${env.BUILD_URL}console">View Console Output</a></p>
                        """,
                        to: 'devops-team@company.com',
                        mimeType: 'text/html'
                    )
                }
            }
        }

        unstable {
            script {
                def message = """
                ⚠️ *DevApp Build Unstable*

                *Build:* ${env.BUILD_NUMBER}
                *Branch:* ${env.GIT_BRANCH}
                *Commit:* ${env.GIT_COMMIT_SHORT}
                *Duration:* ${currentBuild.durationString}

                Some tests failed or quality gates not met.

                <${env.BUILD_URL}|View Build Details>
                """

                slackSend(
                    channel: env.SLACK_CHANNEL,
                    color: 'warning',
                    message: message,
                    teamDomain: 'your-team',
                    token: env.SLACK_CREDENTIALS_ID
                )
            }
        }

        aborted {
            script {
                def message = """
                🛑 *DevApp Build Aborted*

                *Build:* ${env.BUILD_NUMBER}
                *Branch:* ${env.GIT_BRANCH}
                *Commit:* ${env.GIT_COMMIT_SHORT}
                *Duration:* ${currentBuild.durationString}

                <${env.BUILD_URL}|View Build Details>
                """

                slackSend(
                    channel: env.SLACK_CHANNEL,
                    color: '#808080',
                    message: message,
                    teamDomain: 'your-team',
                    token: env.SLACK_CREDENTIALS_ID
                )
            }
        }
    }
}

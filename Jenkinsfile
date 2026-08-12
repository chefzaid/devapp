pipeline {
    agent {
        kubernetes {
            label 'devapp-build-agent'
            defaultContainer 'jnlp'
            yaml '''
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: devapp-build
spec:
  serviceAccountName: jenkins-agent
  containers:
    - name: maven
      image: maven:3.9.11-eclipse-temurin-25
      command: [cat]
      tty: true
      resources:
        requests: {memory: "1Gi", cpu: "500m"}
        limits: {memory: "2Gi", cpu: "2000m"}
      volumeMounts:
        - {name: maven-cache, mountPath: /root/.m2/repository}
        - {name: maven-settings, mountPath: /root/.m2/settings.xml, subPath: settings.xml, readOnly: true}
    - name: node
      image: ghcr.io/puppeteer/puppeteer:24.10.0
      command: [cat]
      tty: true
      resources:
        requests: {memory: "512Mi", cpu: "250m"}
        limits: {memory: "1Gi", cpu: "1000m"}
      securityContext:
        runAsUser: 0
      volumeMounts:
        - {name: npm-cache, mountPath: /root/.npm}
        - {name: npm-config, mountPath: /root/.npmrc, subPath: .npmrc, readOnly: true}
    - name: docker
      image: docker:27-cli
      command: [cat]
      tty: true
      resources:
        requests: {memory: "256Mi", cpu: "250m"}
        limits: {memory: "512Mi", cpu: "500m"}
      volumeMounts:
        - {name: docker-sock, mountPath: /var/run/docker.sock}
        - {name: shared-images, mountPath: /shared}
    - name: k3s-deployer
      image: rancher/kubectl:v1.31.4
      command: [cat]
      tty: true
      resources:
        requests: {memory: "128Mi", cpu: "100m"}
        limits: {memory: "256Mi", cpu: "200m"}
      securityContext:
        privileged: true
      volumeMounts:
        - {name: shared-images, mountPath: /shared}
        - {name: k3s-bin, mountPath: /host-bin, readOnly: true}
        - {name: k3s-containerd, mountPath: /run/k3s}
    - name: git
      image: alpine/git:2.49.1
      command: [cat]
      tty: true
      env:
        - name: GIT_USERNAME
          valueFrom:
            secretKeyRef: {name: devapp-ci-credentials, key: GIT_USERNAME}
        - name: GIT_TOKEN
          valueFrom:
            secretKeyRef: {name: devapp-ci-credentials, key: GIT_TOKEN}
  volumes:
    - name: docker-sock
      hostPath: {path: /var/run/docker.sock}
    - name: shared-images
      emptyDir: {}
    - name: k3s-bin
      hostPath: {path: /usr/local/bin}
    - name: k3s-containerd
      hostPath: {path: /run/k3s}
    - name: maven-cache
      persistentVolumeClaim: {claimName: jenkins-maven-cache}
    - name: npm-cache
      persistentVolumeClaim: {claimName: jenkins-npm-cache}
    - name: maven-settings
      configMap: {name: jenkins-maven-settings}
    - name: npm-config
      configMap: {name: jenkins-npm-config}
'''
        }
    }

    environment {
        K8S_NAMESPACE = 'devapp'
        ARGO_NAMESPACE = 'infra'
        ARGO_APPLICATION = 'devapp'
        GIT_REPOSITORY = 'https://github.com/chefzaid/devapp.git'
    }

    options {
        skipDefaultCheckout(true)
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 75, unit: 'MINUTES')
    }

    triggers {
        pollSCM('H/5 * * * *')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: 'git rev-parse --short=7 HEAD',
                        returnStdout: true
                    ).trim()
                    env.APP_VERSION = "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"
                    env.SKIP_CI = sh(
                        script: "git log -1 --pretty=%B | grep -q '\\[skip ci\\]'",
                        returnStatus: true
                    ) == 0 ? 'true' : 'false'
                    currentBuild.displayName = "#${env.APP_VERSION}"
                    currentBuild.description = env.SKIP_CI == 'true' ?
                        'GitOps image update (build skipped)' : "Commit ${env.GIT_COMMIT_SHORT}"
                }
            }
        }

        stage('Code Quality') {
            when { expression { env.SKIP_CI != 'true' } }
            parallel {
                stage('Backend Tests') {
                    steps {
                        container('maven') {
                            sh 'mvn clean verify -B -Dhttp.proxyHost= -Dhttps.proxyHost='
                        }
                    }
                    post {
                        always {
                            junit testResults: '**/target/surefire-reports/*.xml', allowEmptyResults: true
                        }
                    }
                }
                stage('Frontend Tests') {
                    steps {
                        container('node') {
                            dir('devapp-web') {
                                sh '''
                                    export CHROME_BIN=$(find /home/pptruser/.cache/puppeteer/chrome \
                                        -type f -path '*/chrome-linux*/chrome' | head -1)
                                    test -x "$CHROME_BIN"
                                    export PUPPETEER_EXECUTABLE_PATH="$CHROME_BIN"
                                    CYPRESS_INSTALL_BINARY=0 PUPPETEER_SKIP_DOWNLOAD=true \
                                        npm ci --cache /root/.npm
                                    npm run test:ci
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
            when { expression { env.SKIP_CI != 'true' } }
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
                                sh 'npm run build-prod'
                            }
                        }
                    }
                }
            }
            post {
                success {
                    archiveArtifacts artifacts: 'user-app/target/*.jar,order-app/target/*.jar', fingerprint: true, allowEmptyArchive: true
                }
            }
        }

        stage('Build Images') {
            when { expression { env.SKIP_CI != 'true' } }
            steps {
                container('docker') {
                    sh '''
                        docker build -t "devapp/user-app:${APP_VERSION}" user-app/
                        docker build -t "devapp/order-app:${APP_VERSION}" order-app/
                        docker build -t "devapp/devapp-web:${APP_VERSION}" devapp-web/
                        docker save "devapp/user-app:${APP_VERSION}" > /shared/user-app.tar
                        docker save "devapp/order-app:${APP_VERSION}" > /shared/order-app.tar
                        docker save "devapp/devapp-web:${APP_VERSION}" > /shared/devapp-web.tar
                    '''
                }
            }
        }

        stage('Import Images to K3s') {
            when { expression { env.SKIP_CI != 'true' } }
            steps {
                container('k3s-deployer') {
                    sh '''
                        /host-bin/k3s ctr images import /shared/user-app.tar
                        /host-bin/k3s ctr images import /shared/order-app.tar
                        /host-bin/k3s ctr images import /shared/devapp-web.tar
                    '''
                }
            }
        }

        stage('Commit Desired Version') {
            when { expression { env.SKIP_CI != 'true' } }
            steps {
                container('git') {
                    sh '''
                        git fetch origin main
                        if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
                            echo "origin/main advanced during this build; the next polled build will deploy it" >&2
                            exit 1
                        fi
                        git checkout -B main origin/main
                        scripts/set-image-tags.sh "$APP_VERSION"
                        git config user.name "DevApp Jenkins"
                        git config user.email "jenkins@swirlit.dev"
                        git add deployments/kustomization.yaml
                        git commit -m "deploy: ${APP_VERSION} [skip ci]"

                        set +x
                        export GIT_ASKPASS="$WORKSPACE/.git-askpass"
                        export GIT_TERMINAL_PROMPT=0
                        printf '%s\n' '#!/bin/sh' \
                          'case "$1" in' \
                          '  *Username*) printf "%s\\n" "$GIT_USERNAME" ;;' \
                          '  *) printf "%s\\n" "$GIT_TOKEN" ;;' \
                          'esac' > "$GIT_ASKPASS"
                        chmod 700 "$GIT_ASKPASS"
                        trap 'rm -f "$GIT_ASKPASS"' EXIT
                        git push origin HEAD:main
                        rm -f "$GIT_ASKPASS"
                        trap - EXIT
                        git rev-parse HEAD > .deploy-revision
                        set -x
                    '''
                    script {
                        env.DEPLOY_REVISION = readFile('.deploy-revision').trim()
                    }
                }
            }
        }

        stage('Argo CD Rollout') {
            when { expression { env.SKIP_CI != 'true' } }
            steps {
                container('k3s-deployer') {
                    sh '''
                        kubectl annotate application "$ARGO_APPLICATION" -n "$ARGO_NAMESPACE" \
                            argocd.argoproj.io/refresh=hard --overwrite

                        for attempt in $(seq 1 90); do
                            revision=$(kubectl get application "$ARGO_APPLICATION" -n "$ARGO_NAMESPACE" \
                                -o jsonpath='{.status.sync.revision}' 2>/dev/null || true)
                            sync=$(kubectl get application "$ARGO_APPLICATION" -n "$ARGO_NAMESPACE" \
                                -o jsonpath='{.status.sync.status}' 2>/dev/null || true)
                            health=$(kubectl get application "$ARGO_APPLICATION" -n "$ARGO_NAMESPACE" \
                                -o jsonpath='{.status.health.status}' 2>/dev/null || true)
                            echo "Argo CD: revision=${revision:-unknown} sync=${sync:-unknown} health=${health:-unknown}"
                            if [ "$revision" = "$DEPLOY_REVISION" ] && [ "$sync" = Synced ] && [ "$health" = Healthy ]; then
                                exit 0
                            fi
                            sleep 10
                        done
                        echo "Argo CD did not complete revision $DEPLOY_REVISION within 15 minutes" >&2
                        exit 1
                    '''
                }
            }
        }

        stage('Smoke Tests') {
            when { expression { env.SKIP_CI != 'true' } }
            steps {
                container('k3s-deployer') {
                    sh '''
                        wget -q -O /dev/null --timeout=10 "http://user-app.${K8S_NAMESPACE}.svc.cluster.local:8080/actuator/health"
                        wget -q -O /dev/null --timeout=10 "http://order-app.${K8S_NAMESPACE}.svc.cluster.local:8081/actuator/health"
                        wget -q -O /dev/null --timeout=10 "http://devapp-web.${K8S_NAMESPACE}.svc.cluster.local/"
                    '''
                }
            }
        }
    }

    post {
        always {
            cleanWs(deleteDirs: true, notFailBuild: true)
        }
        success {
            script {
                if (env.SKIP_CI == 'true') {
                    echo 'GitOps image-update commit skipped as intended.'
                } else {
                    echo "DevApp ${env.APP_VERSION} was deployed by Argo CD."
                }
            }
        }
    }
}

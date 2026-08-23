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
  automountServiceAccountToken: true
  securityContext:
    fsGroup: 1000
    seccompProfile: {type: RuntimeDefault}
  containers:
    - name: maven
      image: docker.io/library/maven@sha256:8df9a1dbc464977482f726f28a8a1985dcef4e4e68bdda1ae0330711bcb3a192
      command: [cat]
      tty: true
      resources:
        requests: {memory: "1Gi", cpu: "200m"}
        limits: {memory: "2Gi", cpu: "2000m"}
      volumeMounts:
        - {name: maven-cache, mountPath: /root/.m2/repository}
        - {name: maven-settings, mountPath: /root/.m2/settings.xml, subPath: settings.xml, readOnly: true}
    - name: node
      image: docker.io/library/node@sha256:2a49bdf71e9fd965a58c1703fd9ddd205b34e5782b692a72dd1d248abb0beb43
      command: [cat]
      tty: true
      env:
        - {name: NODE_OPTIONS, value: "--max-old-space-size=1536"}
      resources:
        requests: {memory: "768Mi", cpu: "100m"}
        limits: {memory: "2Gi", cpu: "1000m"}
      securityContext:
        runAsUser: 0
      volumeMounts:
        - {name: npm-cache, mountPath: /root/.npm}
        - {name: npm-config, mountPath: /root/.npmrc, subPath: .npmrc, readOnly: true}
    - name: playwright
      image: mcr.microsoft.com/playwright@sha256:dcc5531e97840b9b5e794f2814476b21571c5124a3fca2267d73041f56e7580e
      command: [cat]
      tty: true
      env:
        - {name: NODE_OPTIONS, value: "--max-old-space-size=1536"}
      resources:
        requests: {memory: "512Mi", cpu: "100m"}
        limits: {memory: "2Gi", cpu: "1500m"}
      securityContext:
        runAsUser: 0
        allowPrivilegeEscalation: false
    - name: kaniko
      image: gcr.io/kaniko-project/executor@sha256:c3109d5926a997b100c4343944e06c6b30a6804b2f9abe0994d3de6ef92b028e
      command: [/busybox/cat]
      tty: true
      resources:
        requests: {memory: "256Mi", cpu: "50m"}
        limits: {memory: "2Gi", cpu: "1000m"}
      securityContext:
        allowPrivilegeEscalation: false
        # Jenkins creates durable-task directories mode 2755, while Kaniko
        # copies, changes ownership, and sets the mode of the Dockerfile under
        # /kaniko. Keep only the filesystem capabilities those operations need.
        capabilities: {drop: ["ALL"], add: ["DAC_OVERRIDE", "CHOWN", "FOWNER"]}
      volumeMounts:
        - {name: registry-auth, mountPath: /kaniko/.docker, readOnly: true}
    - name: kubectl
      image: docker.io/bitnami/kubectl@sha256:175d3e94e675f4d078c60fe097087a2d77dbc9f76d49d4185c83ca79489c2a46
      command: [/bin/sh, -c]
      args: [sleep infinity]
      tty: true
      resources:
        requests: {memory: "128Mi", cpu: "25m"}
        limits: {memory: "256Mi", cpu: "200m"}
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        allowPrivilegeEscalation: false
        capabilities: {drop: ["ALL"]}
    - name: smoke
      image: docker.io/curlimages/curl@sha256:9a1ed35addb45476afa911696297f8e115993df459278ed036182dd2cd22b67b
      command: [cat]
      tty: true
      resources:
        requests: {memory: "16Mi", cpu: "10m"}
        limits: {memory: "64Mi", cpu: "100m"}
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        allowPrivilegeEscalation: false
        capabilities: {drop: ["ALL"]}
    - name: git
      image: docker.io/alpine/git@sha256:c0280cf9572316299b08544065d3bf35db65043d5e3963982ec50647d2746e26
      command: [cat]
      tty: true
      env:
        - {name: HOME, value: /tmp}
        - name: GIT_USERNAME
          valueFrom:
            secretKeyRef: {name: devapp-ci-credentials, key: GIT_USERNAME}
        - name: GIT_TOKEN
          valueFrom:
            secretKeyRef: {name: devapp-ci-credentials, key: GIT_TOKEN}
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        allowPrivilegeEscalation: false
        capabilities: {drop: ["ALL"]}
  volumes:
    - name: registry-auth
      secret: {secretName: jenkins-registry-auth, items: [{key: .dockerconfigjson, path: config.json}]}
    - name: maven-cache
      emptyDir: {sizeLimit: 2Gi}
    - name: npm-cache
      emptyDir: {sizeLimit: 2Gi}
    - name: maven-settings
      secret: {secretName: jenkins-maven-settings}
    - name: npm-config
      secret: {secretName: jenkins-npm-config}
'''
        }
    }

    environment {
        K8S_NAMESPACE = 'devapp'
        ARGO_NAMESPACE = 'infra'
        ARGO_APPLICATION = 'devapp'
        GIT_REPOSITORY = 'http://gitlab.swirlit.internal/root/devapp.git'
        IMAGE_REGISTRY = 'nexus.swirlit.internal:5000/devapp'
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
                                    npm install --global npm@12.0.2
                                    npm ci --cache /root/.npm
                                    npm run test:ci
                                    npm run test:e2e:types
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
                container('kaniko') {
                    sh '''
                        for image in user-app order-app devapp-web; do
                            # The shared workspace is owned by the Jenkins agent UID.
                            # Give Kaniko a root-owned staging copy so its startup
                            # metadata reconciliation stays deterministic. The runtime
                            # Dockerfiles package artifacts already tested above instead
                            # of recompiling the applications inside Kaniko.
                            rm -f "/kaniko/${image}.Dockerfile"
                            cp "$WORKSPACE/$image/Dockerfile.runtime" "/kaniko/${image}.Dockerfile"
                            if [ "$image" = devapp-web ]; then
                                context="$WORKSPACE/devapp-web"
                            else
                                context="$WORKSPACE"
                            fi
                            /kaniko/executor \
                                --context "$context" \
                                --dockerfile "/kaniko/${image}.Dockerfile" \
                                --destination "$IMAGE_REGISTRY/$image:$APP_VERSION" \
                                --insecure \
                                --snapshot-mode=redo \
                                --use-new-run \
                                --cleanup
                        done
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
                container('kubectl') {
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
                container('smoke') {
                    sh '''
                        check_url() {
                            label="$1"
                            url="$2"
                            for attempt in $(seq 1 12); do
                                if curl -fsS --max-time 10 "$url" >/dev/null; then
                                    echo "$label smoke check passed on attempt $attempt"
                                    return 0
                                fi
                                echo "$label is not reachable yet (attempt $attempt/12)" >&2
                                sleep 5
                            done
                            echo "$label failed its smoke check after 12 attempts" >&2
                            return 1
                        }

                        check_url user-app "http://user-app.swirlit.internal:8080/actuator/health"
                        check_url order-app "http://order-app.swirlit.internal:8081/actuator/health"
                        check_url devapp-web "http://devapp.swirlit.internal/"
                    '''
                }
            }
        }

        stage('Browser Acceptance') {
            when { expression { env.SKIP_CI != 'true' } }
            steps {
                container('playwright') {
                    dir('devapp-web') {
                        sh '''
                            trap 'chown -R 1000:1000 test-results playwright-report 2>/dev/null || true' EXIT
                            ingress_ip=$(getent ahostsv4 ingress-nginx-controller.swirlit.internal \
                                | awk 'NR == 1 {print $1}')
                            case "$ingress_ip" in
                                ''|*[!0-9.]*)
                                    echo "Could not resolve the in-cluster ingress IPv4 address" >&2
                                    exit 1
                                    ;;
                            esac
                            printf '%s\t%s\n' "$ingress_ip" devapp.swirlit.dev >> /etc/hosts

                            WEB_URL=https://devapp.swirlit.dev \
                            OIDC_USERNAME=user \
                            OIDC_PASSWORD=password \
                            IGNORE_HTTPS_ERRORS=true \
                            CI=true \
                            npm run test:integration
                        '''
                    }
                }
            }
            post {
                always {
                    junit testResults: 'devapp-web/test-results/playwright-junit.xml', allowEmptyResults: true
                    archiveArtifacts artifacts: 'devapp-web/test-results/playwright/**,devapp-web/playwright-report/**', allowEmptyArchive: true
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

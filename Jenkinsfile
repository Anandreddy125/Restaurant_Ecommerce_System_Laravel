pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
    }

    environment {
        SCANNER_HOME = tool('sonar-scanner')
        SONARQUBE_ENV = "sonar-server"
        NAMESPACE = "testing"
        DOCKER_CREDENTIALS_ID = "docker-test"
    }

    parameters {
        booleanParam(name: 'ROLLBACK', defaultValue: false, description: 'Enable rollback deployment')
        string(name: 'ROLLBACK_TAG', defaultValue: '', description: 'Docker tag to rollback to')
    }

    stages {

        stage('Context') {
            steps {
                echo """
BRANCH_NAME : ${env.BRANCH_NAME}
TAG_NAME    : ${env.TAG_NAME}
ROLLBACK    : ${params.ROLLBACK}
"""
            }
        }

        stage('Setup Staging') {
            when {
                allOf {
                    branch 'staging'
                    expression { !params.ROLLBACK }
                }
            }
            steps {
                script {
                    env.DEPLOY_ENV = "staging"
                    env.IMAGE_NAME = "anrs125/staging-image"
                    env.KUBERNETES_CREDENTIALS_ID = "k3s-testing"
                    env.DEPLOYMENT_FILE = "staging-report.yaml"
                    env.DEPLOYMENT_NAME = "staging-reports-api"
                    env.IMAGE_TAG = "staging-${sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()}"
                }
            }
        }

        stage('Setup Production') {
            when {
                allOf {
                    expression { env.TAG_NAME }
                    expression { !params.ROLLBACK }
                }
            }
            steps {
                script {
                    env.DEPLOY_ENV = "production"
                    env.IMAGE_NAME = "anrs125/staging-image"
                    env.KUBERNETES_CREDENTIALS_ID = "k3s-testing"
                    env.DEPLOYMENT_FILE = "prod-reports.yaml"
                    env.DEPLOYMENT_NAME = "prod-reports-api"
                    env.IMAGE_TAG = env.TAG_NAME
                }
            }
        }

        stage('Rollback Deployment') {
            when {
                expression { params.ROLLBACK && params.ROLLBACK_TAG?.trim() }
            }
            steps {
                script {
                    env.IMAGE_TAG = params.ROLLBACK_TAG
                    echo "🔁 Rolling back to ${env.IMAGE_TAG}"
                }
            }
        }

        stage('SonarQube Analysis') {
            when { expression { env.IMAGE_TAG } }
            steps {
                withSonarQubeEnv("${SONARQUBE_ENV}") {
                    sh """
                        ${SCANNER_HOME}/bin/sonar-scanner \
                        -Dsonar.projectName=${env.DEPLOY_ENV}-reports \
                        -Dsonar.projectKey=${env.DEPLOY_ENV}-reports \
                        -Dsonar.sources=.
                    """
                }
            }
        }

        stage('Quality Gate') {
            when { expression { env.IMAGE_TAG } }
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true, credentialsId: 'sonar-token'
                }
            }
        }

        stage('Docker Build & Push') {
            when {
                expression { env.IMAGE_TAG && !params.ROLLBACK }
            }
            steps {
                script {
                    def imageFull = "${env.IMAGE_NAME}:${env.IMAGE_TAG}"
                    echo "🐳 Building Docker image: ${imageFull}"

                    sh """
                        docker build --pull --no-cache -t ${imageFull} .
                        docker push ${imageFull}
                    """
                }
            }
        }

        stage('Deploy to Kubernetes') {
            when {
                expression { env.IMAGE_TAG }
            }
            steps {
                dir('deployments') {
                    withKubeConfig(credentialsId: env.KUBERNETES_CREDENTIALS_ID) {
                        sh """
                            sed -i 's|image: ${env.IMAGE_NAME}:.*|image: ${env.IMAGE_NAME}:${env.IMAGE_TAG}|' ${env.DEPLOYMENT_FILE}

                            kubectl apply -f ${env.DEPLOYMENT_FILE} -n ${env.NAMESPACE}

                            kubectl rollout status deployment/${env.DEPLOYMENT_NAME} \
                              -n ${env.NAMESPACE} \
                              --timeout=10m || {
                                echo "Rollout failed. Rolling back..."
                                kubectl rollout undo deployment/${env.DEPLOYMENT_NAME} -n ${env.NAMESPACE}
                                exit 1
                              }
                        """
                    }
                }
            }
        }
    }
}

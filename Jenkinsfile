pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
    }

    environment {
        SCANNER_HOME          = tool('sonar-scanner')
        SONARQUBE_ENV         = "sonar-server"
        NAMESPACE             = "testing"
        DOCKER_CREDENTIALS_ID = "docker-test"
    }

    parameters {
        booleanParam(
            name: 'ROLLBACK',
            defaultValue: false,
            description: 'Enable rollback deployment'
        )
        string(
            name: 'ROLLBACK_TAG',
            defaultValue: '',
            description: 'Docker tag to rollback to'
        )
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
                    env.DEPLOY_ENV                = "staging"
                    env.IMAGE_NAME                = "anrs125/staging-image"
                    env.KUBERNETES_CREDENTIALS_ID = "k3s-testing"
                    env.DEPLOYMENT_FILE           = "staging-report.yaml"
                    env.DEPLOYMENT_NAME           = "staging-reports-api"
                    env.IMAGE_TAG                 = "staging-${sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()}"
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
                    env.DEPLOY_ENV                = "production"
                    env.IMAGE_NAME                = "anrs125/staging-image"
                    env.KUBERNETES_CREDENTIALS_ID = "k3s-testing"
                    env.DEPLOYMENT_FILE           = "prod-reports.yaml"
                    env.DEPLOYMENT_NAME           = "prod-reports-api"
                    env.IMAGE_TAG                 = env.TAG_NAME
                }
            }
        }

        stage('Rollback Setup') {
            when {
                expression { params.ROLLBACK && params.ROLLBACK_TAG?.trim() }
            }
            steps {
                script {
                    env.IMAGE_TAG = params.ROLLBACK_TAG
                    echo "Rollback image tag set to ${env.IMAGE_TAG}"
                }
            }
        }

   //     stage('SonarQube Analysis') {
   //         when { expression { env.IMAGE_TAG } }
   //         steps {
   //             withSonarQubeEnv("${SONARQUBE_ENV}") {
   //                 sh """
   //                     ${SCANNER_HOME}/bin/sonar-scanner \
   //                     -Dsonar.projectName=${env.DEPLOY_ENV}-reports \
   //                     -Dsonar.projectKey=${env.DEPLOY_ENV}-reports \
   //                     -Dsonar.sources=.
   //                 """
   //             }
   //         }
   //     }

   //     stage('Quality Gate') {
   //         when { expression { env.IMAGE_TAG } }
   //         steps {
   //             timeout(time: 10, unit: 'MINUTES') {
   //                 waitForQualityGate abortPipeline: true, credentialsId: 'sonar-token'
   //             }
   //         }
   //     }

        stage('Docker Login') {
            when {
                expression { env.IMAGE_TAG && !params.ROLLBACK }
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: env.DOCKER_CREDENTIALS_ID,
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASSWORD'
                )]) {
                    sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USER" --password-stdin'
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
                    sh """
                        docker build --pull --no-cache -t ${imageFull} .
                        docker push ${imageFull}
                        docker logout
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
                            sed -i 's|image: .*|image: ${env.IMAGE_NAME}:${env.IMAGE_TAG}|' ${env.DEPLOYMENT_FILE}
                            kubectl apply -f ${env.DEPLOYMENT_FILE} -n ${env.NAMESPACE}
                            kubectl rollout status deployment/${env.DEPLOYMENT_NAME} -n ${env.NAMESPACE} --timeout=10m
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            slackSend(
                channel: '#jenkins-alerts',
                color: '#36A64F',
                tokenCredentialId: 'slack-token',
                message: """
✅ Deployment Successful
Env: ${env.DEPLOY_ENV}
Image: ${env.IMAGE_NAME}:${env.IMAGE_TAG}
${env.BUILD_URL}
"""
            )
        }

        failure {
            slackSend(
                channel: '#jenkins-alerts',
                color: '#FF0000',
                tokenCredentialId: 'slack-token',
                message: """
❌ Deployment Failed
Env: ${env.DEPLOY_ENV}
${env.BUILD_URL}
"""
            )
        }

        always {
            cleanWs()
        }
    }
}

//testing with Ai team again testing some issue on jenkins server
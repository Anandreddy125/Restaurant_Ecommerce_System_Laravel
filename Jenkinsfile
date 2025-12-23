pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
    }

    environment {
        IMAGE_NAME = "anrs125/testing-repo"
        DOCKER_CREDENTIALS_ID = "docker-test"
    }

    stages {

        stage('Show Context') {
            steps {
                echo """
==============================
 BRANCH_NAME : ${env.BRANCH_NAME}
 TAG_NAME    : ${env.TAG_NAME}
==============================
"""
            }
        }

        /* ================= STAGING ================= */
        stage('Build Staging Image') {
            when {
                branch 'staging'
            }
            steps {
                script {
                    def commitId = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()

                    env.IMAGE_TAG = "staging-${commitId}"
                    echo "Staging Image Tag: ${IMAGE_NAME}:${IMAGE_TAG}"
                }
            }
        }

        /* ================= PRODUCTION (TAG ONLY) ================= */
        stage('Validate Production Tag') {
            when {
                expression { env.TAG_NAME }
            }
            steps {
                script {
                    env.IMAGE_TAG = env.TAG_NAME
                    echo "Production Tag Detected: ${IMAGE_TAG}"
                }
            }
        }

        /* ================= DOCKER BUILD & PUSH ================= */
        stage('Docker Build & Push') {
            when {
                expression { env.IMAGE_TAG }
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: env.DOCKER_CREDENTIALS_ID,
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASSWORD'
                )]) {
                    sh """
                        echo "\$DOCKER_PASSWORD" | docker login -u "\$DOCKER_USER" --password-stdin
                        docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
                        docker push ${IMAGE_NAME}:${IMAGE_TAG}
                    """
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
    }
}


//testing jenkinspipeline
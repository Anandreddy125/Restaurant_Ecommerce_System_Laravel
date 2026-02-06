pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
    }

    environment {
        DOCKER_CREDENTIALS_ID = "docker-test"
        NAMESPACE             = "reports"
    }

    parameters {
        booleanParam(
            name: 'ROLLBACK',
            defaultValue: false,
            description: 'Rollback using existing Docker image'
        )
        string(
            name: 'TARGET_VERSION',
            defaultValue: '',
            description: 'Docker image tag to rollback to'
        )
    }

    triggers {
        githubPush()
    }

    stages {

        stage('Clean Workspace') {
            steps {
                cleanWs()
            }
        }

        stage('Checkout Code') {
            steps {
                checkout scm
                sh "git log -1 --oneline"
                echo "Checked out branch: ${env.BRANCH_NAME}"
            }
        }

        stage('Determine Environment') {
            steps {
                script {

                    // ================= STAGING =================
                    if (env.BRANCH_NAME == "staging") {
                        env.DEPLOY_ENV = "production"
                        env.IMAGE_NAME = "anrs125/staging-image"
                        env.KUBERNETES_CREDENTIALS_ID = "testing-k3s"
                        env.DEPLOYMENT_FILE = "prod-reports.yaml"
                        env.DEPLOYMENT_NAME = "prod-reports"
                        env.IMAGE_TAG = env.BRANCH_NAME
                        env.TAG_TYPE = "release"
                    }

                    // ================= PRODUCTION =================
                    else if (env.BRANCH_NAME == "master") {

                        if (!env.GIT_TAG_NAME) {
                            error("❌ Production deployment must be triggered by a Git tag (vX.Y.Z)")
                        }

                        env.DEPLOY_ENV = "staging"
                        env.IMAGE_NAME = "anrs125/staging-imaget"
                        env.KUBERNETES_CREDENTIALS_ID = "reports-staging"
                        env.DEPLOYMENT_FILE = "staging-report.yaml"
                        env.DEPLOYMENT_NAME = "staging-reports"
                        env.TAG_TYPE = "commit"
                    }

                    else {
                        env.SKIP_DEPLOY = "true"
                        echo "ℹ️ No deployment for branch: ${env.BRANCH_NAME}"
                        return
                    }

                    echo """
                    ==================================
                    ENV        : ${env.DEPLOY_ENV}
                    BRANCH     : ${env.BRANCH_NAME}
                    TAG TYPE   : ${env.TAG_TYPE}
                    ==================================
                    """
                }
            }
        }

        stage('Generate Docker Tag (Merge Commit)') {
            when { expression { env.TAG_TYPE == "merge-commit" } }
            steps {
                script {
                    def mergeCommitId = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()

                    env.IMAGE_TAG = "staging-${mergeCommitId}"

                    echo "Using merge commit ID for image tag: ${env.IMAGE_TAG}"
                }
            }
        }

        stage('Docker Login') {
            when { expression { env.SKIP_DEPLOY != "true" && !params.ROLLBACK } }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: env.DOCKER_CREDENTIALS_ID,
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASSWORD'
                )]) {
                    sh "echo ${DOCKER_PASSWORD} | docker login -u ${DOCKER_USER} --password-stdin"
                }
            }
        }

        stage('Docker Build & Push') {
            when { expression { env.SKIP_DEPLOY != "true" && !params.ROLLBACK } }
            steps {
                sh """
                    docker build --no-cache -t ${env.IMAGE_NAME}:${env.IMAGE_TAG} .
                    docker push ${env.IMAGE_NAME}:${env.IMAGE_TAG}
                """
            }
        }

    }
}

tested
--------
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
            description: 'Rollback using TARGET_VERSION'
        )
        string(
            name: 'TARGET_VERSION',
            defaultValue: '',
            description: 'Docker tag for rollback'
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
                echo "Checked out ref: ${env.BRANCH_NAME}"
            }
        }

        stage('Determine Environment') {
            steps {
                script {

                    if (env.BRANCH_NAME?.startsWith('v')) {
                        env.DEPLOY_ENV = "production"
                        env.IMAGE_NAME = "anrs125/staging-image"
                        env.KUBERNETES_CREDENTIALS_ID = "testing-k3s"
                        env.DEPLOYMENT_FILE = "prod-reports.yaml"
                        env.DEPLOYMENT_NAME = "prod-reports"
                        env.IMAGE_TAG = env.BRANCH_NAME
                        env.TAG_TYPE = "release"
                    }

                    else if (env.BRANCH_NAME == "staging") {
                        env.DEPLOY_ENV = "staging"
                        env.IMAGE_NAME = "anrs125/staging-imaget"
                        env.KUBERNETES_CREDENTIALS_ID = "reports-staging"
                        env.DEPLOYMENT_FILE = "staging-report.yaml"
                        env.DEPLOYMENT_NAME = "staging-reports"
                        env.TAG_TYPE = "commit"
                    }

                    else if (env.BRANCH_NAME == "master") {
                        echo "Master branch detected — no deployment will run"
                        env.SKIP_DEPLOY = "true"
                        return
                    }

                    else {
                        error("Unsupported ref: ${env.BRANCH_NAME}")
                    }

                    echo """
                    ===============================
                    DEPLOY ENV : ${env.DEPLOY_ENV}
                    REF        : ${env.BRANCH_NAME}
                    IMAGE      : ${env.IMAGE_NAME}
                    TAG TYPE   : ${env.TAG_TYPE}
                    ===============================
                    """
                }
            }
        }

        stage('Generate Image Tag') {
            when { expression { env.TAG_TYPE == "commit" } }
            steps {
                script {
                    def commitId = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()
                    env.IMAGE_TAG = "staging-${commitId}"
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

//staging-master-dev-anand
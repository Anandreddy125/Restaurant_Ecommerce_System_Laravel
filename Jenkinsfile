pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
    }

    environment {
        DOCKER_CREDENTIALS_ID = "docker-test"
        SONARQUBE_ENV         = "sonar-server"
        NAMESPACE             = "reports"
    }

    parameters {
        booleanParam(name: 'ROLLBACK', defaultValue: false, description: 'Rollback using TARGET_VERSION')
        string(name: 'TARGET_VERSION', defaultValue: '', description: 'Docker tag for rollback')
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
                echo "BRANCH_NAME = ${env.BRANCH_NAME}"
                echo "TAG_NAME    = ${env.TAG_NAME}"
            }
        }

        /* =====================================================
           Decide if pipeline should run
           ===================================================== */
        stage('Validate Trigger') {
            steps {
                script {
                    // Production → ONLY tag
                    if (env.TAG_NAME) {
                        env.PIPELINE_MODE = "production"
                        return
                    }

                    // Staging → branch push
                    if (env.BRANCH_NAME == "staging") {
                        env.PIPELINE_MODE = "staging"
                        return
                    }

                    // Everything else → skip
                    echo "Skipping build for ${env.BRANCH_NAME}"
                    currentBuild.result = 'NOT_BUILT'
                    error("Unsupported trigger")
                }
            }
        }

        stage('Determine Environment') {
            steps {
                script {
                    if (env.PIPELINE_MODE == "production") {
                        env.DEPLOY_ENV = "production"
                        env.IMAGE_NAME = "anrs125/staging-image"
                        env.IMAGE_TAG  = env.TAG_NAME
                        env.KUBERNETES_CREDENTIALS_ID = "testing-k3s"
                        env.DEPLOYMENT_FILE = "prod-reports.yaml"
                        env.DEPLOYMENT_NAME = "prod-reports"
                        env.TAG_TYPE = "release"
                    }

                    if (env.PIPELINE_MODE == "staging") {
                        env.DEPLOY_ENV = "staging"
                        env.IMAGE_NAME = "anrs125/staging-imaget"
                        env.KUBERNETES_CREDENTIALS_ID = "reports-staging"
                        env.DEPLOYMENT_FILE = "staging-report.yaml"
                        env.DEPLOYMENT_NAME = "staging-reports"
                        env.TAG_TYPE = "commit"
                    }

                    echo """
                    ===============================
                    MODE       : ${env.PIPELINE_MODE}
                    DEPLOY ENV : ${env.DEPLOY_ENV}
                    REF        : ${env.BRANCH_NAME ?: env.TAG_NAME}
                    IMAGE      : ${env.IMAGE_NAME}
                    TAG TYPE   : ${env.TAG_TYPE}
                    ===============================
                    """
                }
            }
        }

        stage('Generate Image Tag (Staging)') {
            when { expression { env.PIPELINE_MODE == "staging" } }
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
            when { expression { !params.ROLLBACK } }
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
            when { expression { !params.ROLLBACK } }
            steps {
                sh """
                    docker build --no-cache -t ${env.IMAGE_NAME}:${env.IMAGE_TAG} .
                    docker push ${env.IMAGE_NAME}:${env.IMAGE_TAG}
                """
            }
        }

        stage('Rollback') {
            when { expression { params.ROLLBACK } }
            steps {
                script {
                    if (!params.TARGET_VERSION) {
                        error("TARGET_VERSION is required for rollback")
                    }
                    echo "Rolling back to version ${params.TARGET_VERSION}"
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


//updated jenkinsfile change happens
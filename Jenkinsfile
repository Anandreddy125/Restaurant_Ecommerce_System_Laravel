pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
    }

    environment {
        GIT_REPO              = "https://github.com/Anandreddy125/Restaurant_Ecommerce_System_Laravel.git"
        GIT_CREDENTIALS_ID    = "github-anand"
        DOCKER_CREDENTIALS_ID = "docker-test"
    }

    parameters {
        choice(
            name: 'BRANCH_PARAM',
            choices: ['staging', 'master'],
            description: 'Select branch to build'
        )
        booleanParam(
            name: 'ROLLBACK',
            defaultValue: false,
            description: 'Rollback to TARGET_VERSION'
        )
        string(
            name: 'TARGET_VERSION',
            defaultValue: '',
            description: 'Docker tag for rollback'
        )
    }

    stages {

        stage('Clean Workspace') {
            steps {
                cleanWs()
            }
        }

        stage('Checkout Code') {
            steps {
                script {
                    def branchName = params.BRANCH_PARAM
                    echo "🔹 Checking out branch: ${branchName}"

                    checkout([
                        $class: 'GitSCM',
                        branches: [[name: "*/${branchName}"]],
                        userRemoteConfigs: [[
                            url: env.GIT_REPO,
                            credentialsId: env.GIT_CREDENTIALS_ID
                        ]]
                    ])

                    env.ACTUAL_BRANCH = branchName
                }
            }
        }

        stage('Determine Environment') {
            steps {
                script {
                    if (env.ACTUAL_BRANCH == "staging") {
                        env.DEPLOY_ENV = "staging"
                        env.IMAGE_NAME = "anrs125/testing-repo"
                        env.TAG_TYPE   = "commit"
                    } else if (env.ACTUAL_BRANCH == "master") {
                        env.DEPLOY_ENV = "production"
                        env.IMAGE_NAME = "anrs125/testing-repo"
                        env.TAG_TYPE   = "release"
                    } else {
                        error("Unsupported branch: ${env.ACTUAL_BRANCH}")
                    }

                    echo """
=============================
 Environment Configuration
=============================
 Branch      : ${env.ACTUAL_BRANCH}
 Deploy Env  : ${env.DEPLOY_ENV}
 Image Repo  : ${env.IMAGE_NAME}
 Tag Mode    : ${env.TAG_TYPE}
=============================
"""
                }
            }
        }

        stage('Generate Docker Tag') {
            steps {
                script {
                    def commitId = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()

                    if (params.ROLLBACK) {
                        if (!params.TARGET_VERSION?.trim()) {
                            error("Rollback enabled but TARGET_VERSION not provided")
                        }
                        env.IMAGE_TAG = params.TARGET_VERSION.trim()
                    }
                    else if (env.TAG_TYPE == "commit") {
                        env.IMAGE_TAG = "staging-${commitId}"
                    }
                    else {
                        def gitTag = sh(
                            script: "git describe --tags --exact-match HEAD 2>/dev/null || true",
                            returnStdout: true
                        ).trim()

                        if (!gitTag) {
                            error("Production builds require a Git tag")
                        }
                        env.IMAGE_TAG = gitTag
                    }

                    echo "🚀 Final Docker Image: ${env.IMAGE_NAME}:${env.IMAGE_TAG}"
                }
            }
        }
    }
}

// jenkinsfile 
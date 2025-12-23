stage('Test Kubernetes Connection') {
    when { expression { env.IMAGE_TAG } }
    steps {
        withKubeConfig(credentialsId: env.KUBERNETES_CREDENTIALS_ID) {
            sh """
                kubectl --insecure-skip-tls-verify get nodes
                kubectl --insecure-skip-tls-verify get ns
                kubectl --insecure-skip-tls-verify get pods -A
            """
        }
    }
}

stage('Deploy Application') {
    when { expression { env.IMAGE_TAG } }
    steps {
        dir('deployments') {
            withKubeConfig(credentialsId: env.KUBERNETES_CREDENTIALS_ID) {
                sh """
                    sed -i 's|image: .*|image: ${env.IMAGE_NAME}:${env.IMAGE_TAG}|g' ${env.DEPLOYMENT_FILE}
                    kubectl apply -f ${env.DEPLOYMENT_FILE} -n ${env.NAMESPACE} --validate=false
                    kubectl rollout status deployment/${env.DEPLOYMENT_NAME} -n ${env.NAMESPACE} --timeout=10m
                """
            }
        }
    }
}
// sonarqube down
// 
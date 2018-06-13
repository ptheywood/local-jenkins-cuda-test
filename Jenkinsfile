pipeline {
    agent { dockerfile true }
    stages {
        stage('Test') {
            steps {
                sh 'git --version'
                sh 'ls -la /dev | grep nvidia'
            }
        }
    }
}

pipeline {
    agent { dockerfile true }
    stages {

        stage('Build') {
            steps {
                sh 'nvcc --version'
                sh 'make' 
                archiveArtifacts artifacts: '**/bin/*/*', fingerprint: true 
            }
        }

        stage('Test') {
            steps {
                sh './run_test.sh'
            }
        }
    }
}

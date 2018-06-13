pipeline {
    agent { dockerfile true }
    stages {

         stage('NVCC check') {
            steps {
                sh 'nvcc --version'
            }
        }

        stage('nvidia-smi') {
            steps {
                sh 'nvidia-smi'
            }
        }

        stage('Build') {
            steps {
                sh 'nvcc --version'
                sh 'make' 
                archiveArtifacts artifacts: '**/bin/*/*', fingerprint: true 
            }
        }

        stage('Test') {
            steps {
                sh 'nvidia-smi'
                sh './run_test.sh'
            }
        }
    }
}

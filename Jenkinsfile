pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                sh '. /etc/profile.d/modules.sh || true'
                sh 'echo $MODULESHOME'
                sh 'module load libs/CUDA/9.0/binary || true'
                sh 'export PATH="/usr/local/cuda-9.0/bin/:$PATH"'
                sh 'export LD_LIBRARY_PATH="/usr/local/cuda-9.0/lib64/:$LD_LIBRARY_PATH"'
                sh 'echo $PATH' 
                sh 'which nvcc' 
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

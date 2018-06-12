pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                sh '. /etc/profile.d/modules.sh || true'
                sh 'echo $MODULESHOME'
                sh 'module load libs/CUDA/9.0/binary || true'
                sh 'make' 
                archiveArtifacts artifacts: '**/bin/*/*', fingerprint: true 
            }
        }

        stage('Test') {
            steps {
                /* `make check` returns non-zero on test failures,
                * using `true` to allow the Pipeline to continue nonetheless
                */
                sh './run_test.sh'
            }
        }
    }
}

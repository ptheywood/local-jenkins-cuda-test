pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                bash '. /etc/profile.d/modules.sh || true'
                bash 'echo $MODULESHOME'
                bash 'module load libs/CUDA/9.0/binary || true'
                bash 'make' 
                archiveArtifacts artifacts: '**/bin/*/*', fingerprint: true 
            }
        }

        stage('Test') {
            steps {
                /* `make check` returns non-zero on test failures,
                * using `true` to allow the Pipeline to continue nonetheless
                */
                bash './run_test.sh'
            }
        }
    }
}

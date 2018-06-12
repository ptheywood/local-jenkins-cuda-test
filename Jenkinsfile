pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
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

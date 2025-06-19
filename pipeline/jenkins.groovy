pipeline {
  agent {
    kubernetes {
      yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: dind
      image: docker:dind
      securityContext:
        privileged: true
      args:
        - "--host=tcp://0.0.0.0:2375"
    - name: jenkins
      image: ghcr.io/sarco3t/jenkins-go-agent:v0.0.3
      command:
        - sleep
      args:
        - infinity
      env:
        - name: DOCKER_HOST
          value: "tcp://localhost:2375"
"""
      defaultContainer 'jenkins'
    }
  }
        
    parameters {
        choice(
            name: 'TARGETOS',
            choices: ['linux', 'darwin', 'windows'],
            description: 'Target operating system'
        )
        choice(
            name: 'TARGETARCH',
            choices: ['amd64', 'arm64'],
            description: 'Target architecture'
        )
    }


    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Run golangci-lint') {
            steps {
                dir("${env.WORKSPACE}") {
                    sh 'export GIT_DIR=.git && export GIT_WORK_TREE=. && golangci-lint run --timeout=5m'
                }
            }
        }

        stage('Build') {
            steps {
                dir("${env.WORKSPACE}") {
                sh """
                bash -c '
                    export GIT_DIR=.git
                    export GIT_WORK_TREE=.
                    git config --global --add safe.directory "\$(pwd)"
                    make image TARGETOS=${params.TARGETOS} TARGETARCH=${params.TARGETARCH}
                '
                """
                }
            }
        }
    }

    post {
        failure {
            echo 'Build failed!'
        }
        success {
            echo 'Build succeeded!'
        }
    }
}
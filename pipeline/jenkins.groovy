pipeline {
    agent {
          kubernetes {
    yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: go-agent
    image: ghcr.io/sarco3t/jenkins-go-agent:v0.0.3-1c89396
    command: ["sleep"]
    args: ["infinity"]
    volumeMounts:
    - mountPath: /var/run/docker.sock
      name: docker-sock
  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
"""
    defaultContainer 'go-agent'
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
                sh 'golangci-lint run --timeout=5m'
            }
        }

        stage('Build') {
            steps {
                dir("${env.WORKSPACE}") {
                    sh "make image TARGETOS=${params.TARGETOS} TARGETARCH=${params.TARGETARCH}"
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
pipeline {
    agent any
    
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
        stage('Install tools') {
            steps {
                sh '''
                apt-get update
                apt-get install -y make wget curl git
                '''
        }
        }
        
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Set up Go') {
            steps {
                sh '''
                wget -q https://go.dev/dl/go1.22.4.linux-amd64.tar.gz
                sudo rm -rf /usr/local/go
                sudo tar -C /usr/local -xzf go1.22.4.linux-amd64.tar.gz
                export PATH=/usr/local/go/bin:$PATH
                go version
                go env
                '''
            }
        }

        stage('Run golangci-lint') {
            steps {
                sh '''
                curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin latest
                $(go env GOPATH)/bin/golangci-lint run --timeout=5m
                '''
            }
        }

        stage('Build') {
            steps {
                sh 'make build TARGETARCH=$TARGETARCH TARGETOS=$TARGETOS'
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
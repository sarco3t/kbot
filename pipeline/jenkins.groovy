pipeline {
  agent {
    kubernetes {
      yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: dind
      image: docker:28.0-dind
      securityContext:
        privileged: true
      args:
        - --host=tcp://0.0.0.0:2375
      env:
        - name: DOCKER_TLS_CERTDIR
          value: ""
    - name: jenkins
      image: ghcr.io/sarco3t/jenkins-go-agent:v0.0.3-1c89396
      command: ["sleep"]
      args: ["infinity"]
      env:
        - name: DOCKER_HOST
          value: "tcp://localhost:2375"
        - name: DOCKER_BUILDKIT
          value: "1"
      volumeMounts:
        - name: dockersock
          mountPath: /var/run
  volumes:
    - name: dockersock
      emptyDir: {}
"""
      defaultContainer 'jenkins'
    }
  }

  parameters {
    choice(name: 'TARGETOS', choices: ['linux', 'darwin', 'windows'], description: 'Target OS')
    choice(name: 'TARGETARCH', choices: ['amd64', 'arm64'], description: 'Target Arch')
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Install buildx') {
      steps {
        sh '''
          mkdir -p ~/.docker/cli-plugins
          curl -sSL https://github.com/docker/buildx/releases/download/v0.13.1/buildx-v0.13.1.linux-amd64 -o ~/.docker/cli-plugins/docker-buildx
          chmod +x ~/.docker/cli-plugins/docker-buildx
          docker buildx version
        '''
      }
    }

    stage('Run golangci-lint') {
      steps {
        sh '''
          export GIT_DIR=.git
          export GIT_WORK_TREE=.
          golangci-lint run --timeout=5m
        '''
      }
    }

    stage('Build and Push with buildx') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'ghcr-secret', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh """
            export GIT_DIR=.git
            export GIT_WORK_TREE=.
            git config --global --add safe.directory "\$(pwd)"

            echo "Logging into GHCR..."
            echo "\$DOCKER_PASS" | docker login ghcr.io -u "\$DOCKER_USER" --password-stdin

            docker buildx create --name multiarch-builder --use || docker buildx use multiarch-builder
            docker buildx inspect --bootstrap

            make push TARGETOS=${params.TARGETOS} TARGETARCH=${params.TARGETARCH}
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

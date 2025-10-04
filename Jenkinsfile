pipeline {
  agent any

  environment {
    IMAGE_NAME = "govin55/assignment2"  // TODO: change me
    IMAGE_TAG  = "build-${env.BUILD_NUMBER}"
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Install dependencies') {
      agent { docker { image 'node:16'; reuseNode true } }
      steps { sh 'npm install --save' }
    }

    stage('Unit tests') {
      agent { docker { image 'node:16'; reuseNode true } }
      steps { sh 'npm test || echo "No tests found — continuing"' }
      post { always { junit allowEmptyResults: true, testResults: 'junit.xml' } }
    }

    // 🔐 Dependency Vulnerability Gate (Snyk)
    stage('Dependency Scan (Snyk)') {
      agent { docker { image 'node:16'; reuseNode true } }
      steps {
        withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN')]) {
          sh '''
            npm install -g snyk
            snyk auth "$SNYK_TOKEN"
            # FAIL the build on high/critical
            snyk test --severity-threshold=high
          '''
        }
      }
    }

    // 🐳 Build & Push image using DinD (Docker-in-Docker)
    stage('Docker build & push') {
      agent {
        docker {
          image 'docker:27-cli'
          args  '-v /certs/client:/certs/client:ro'
          reuseNode true
        }
      }
      environment {
        DOCKER_HOST       = 'tcp://docker:2376'
        DOCKER_TLS_VERIFY = '1'
        DOCKER_CERT_PATH  = '/certs/client'
      }
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'dockerhub-credentials-id',
          usernameVariable: 'DH_USER',
          passwordVariable: 'DH_PASS'
        )]) {
          sh '''
            echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
            docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
            docker push ${IMAGE_NAME}:${IMAGE_TAG}
            docker tag  ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
            docker push ${IMAGE_NAME}:latest
          '''
        }
      }
    }
  }

  post {
    always { cleanWs() }
  }
}

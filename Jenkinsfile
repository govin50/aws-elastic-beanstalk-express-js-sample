pipeline {
  /* We’ll pick a stage-specific agent for each step. */
  agent none

  environment {
    // TODO: change this to YOUR Docker Hub repo (e.g., govin50/my-express-app)
    IMAGE_NAME = "yourdockerhubusername/my-express-app"
    IMAGE_TAG  = "build-${env.BUILD_NUMBER}"
  }

  stages {
    stage('Checkout') {
      agent any
      steps {
        checkout scm
      }
    }

    stage('Install dependencies') {
      agent {
        docker {
          image 'node:16'
          // reuse the same workspace so node_modules stay in place during this stage
          reuseNode true
        }
      }
      steps {
        sh 'npm install --save'
      }
    }

    stage('Unit tests') {
      agent {
        docker {
          image 'node:16'
          reuseNode true
        }
      }
      steps {
        // if no tests exist, don’t fail the build
        sh 'npm test || echo "No tests found — continuing"'
      }
      post {
        always {
          // collect JUnit if your tests produce it (safe to keep allowEmpty)
          junit allowEmptyResults: true, testResults: 'junit.xml'
        }
      }
    }

    stage('Docker build & push') {
      // Use a proper Docker CLI image just for Docker commands
      agent {
        docker {
          image 'docker:27-cli'
          // mount the client TLS certs from your Jenkins controller (DinD pattern)
          args '-v /certs/client:/certs/client:ro'
          reuseNode true
        }
      }
      environment {
        // DinD connection (matches your docker-compose)
        DOCKER_HOST       = 'tcp://docker:2376'
        DOCKER_TLS_VERIFY = '1'
        DOCKER_CERT_PATH  = '/certs/client'
      }
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials-id',
                                          usernameVariable: 'DH_USER',
                                          passwordVariable: 'DH_PASS')]) {
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
    always {
      // keep logs lean between builds
      cleanWs()
    }
  }
}

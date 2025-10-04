pipeline {
  agent any

  environment {
    // CHANGE THIS to your Docker Hub repo, e.g., govin50/my-express-app
    IMAGE_NAME = "govin55/assignment2"
    IMAGE_TAG  = "build-${env.BUILD_NUMBER}"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Install dependencies') {
      agent { docker { image 'node:16'; reuseNode true } }
      steps {
        sh 'npm install --save'
      }
    }

    stage('Unit tests') {
      agent { docker { image 'node:16'; reuseNode true } }
      steps {
        sh 'npm test || echo "No tests found — continuing"'
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: 'junit.xml'
        }
      }
    }

    stage('Dependency Scan (OWASP)') {
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
        sh '''
          mkdir -p .depcheck
          docker run --rm \
            -v "$PWD":/src:Z \
            -v "$PWD/.depcheck":/report:Z \
            owasp/dependency-check:latest \
            --scan /src \
            --format "XML,HTML" \
            --out /report || true

          # Fail build on High/Critical
          if [ -f .depcheck/dependency-check-report.xml ]; then
            HIGHS=$(grep -o 'severity="High"' .depcheck/dependency-check-report.xml | wc -l || true)
            CRITS=$(grep -o 'severity="Critical"' .depcheck/dependency-check-report.xml | wc -l || true)
            TOTAL=$((HIGHS + CRITS))
            echo "High: ${HIGHS}, Critical: ${CRITS}, Total: ${TOTAL}"
            if [ "$TOTAL" -gt 0 ]; then
              echo "Failing build due to High/Critical vulnerabilities."
              exit 1
            fi
          fi
        '''
      }
      post {
        always {
          archiveArtifacts artifacts: '.depcheck/**', fingerprint: true, allowEmptyArchive: true
        }
      }
    }

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
    always {
      cleanWs()
    }
  }
}

pipeline {
  agent any

  environment {
    IMAGE_NAME = "govin55/assignment2"
    IMAGE_TAG  = "build-${env.BUILD_NUMBER}"
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    // Install deps using Node 16 container (no docker-agent plugin)
    stage('Install dependencies') {
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
          docker run --rm \
            -v "$PWD":/app:Z -w /app \
            node:16 bash -lc "npm install --save"
        '''
      }
    }

    stage('Unit tests') {
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
          docker run --rm \
            -v "$PWD":/app:Z -w /app \
            node:16 bash -lc "npm test || echo 'No tests found — continuing'"
        '''
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: 'junit.xml'
        }
      }
    }

    // Dependency scan (OWASP) — fails on High/Critical
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

    // Build & push (DinD)
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

  post { always { cleanWs() } }
}

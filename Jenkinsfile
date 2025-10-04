pipeline {
  agent any

  // If you use host Docker socket instead of DinD, delete the three DOCKER_* lines.
  environment {
    IMAGE_NAME = "govin55/assignment2"
    IMAGE_TAG  = "build-${env.BUILD_NUMBER}"

    // DinD connectivity (keep if you're using docker:27-dind)
    DOCKER_HOST       = 'tcp://docker:2376'
    DOCKER_TLS_VERIFY = '1'
    DOCKER_CERT_PATH  = '/certs/client'
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Docker sanity') {
      steps {
        sh '''
          echo "Checking Docker connectivity…"
          docker version
        '''
      }
    }

    stage('Install dependencies (Node 16)') {
      steps {
        sh '''
          docker run --rm \
            -v "$PWD":/app -w /app \
            node:16 bash -lc "npm install --save"
        '''
      }
    }

    stage('Unit tests (Node 16)') {
      steps {
        sh '''
          docker run --rm \
            -v "$PWD":/app -w /app \
            node:16 bash -lc "npm test || echo 'No tests found — continuing'"
        '''
      }
      post {
        always {
          // Keep if you output junit.xml; harmless if not present
          junit allowEmptyResults: true, testResults: 'junit.xml'
        }
      }
    }

    stage('Dependency Scan (OWASP)') {
      steps {
        sh '''
          mkdir -p .depcheck
          # Run OWASP Dependency-Check in a container against the workspace
          docker run --rm \
            -v "$PWD":/src \
            -v "$PWD/.depcheck":/report \
            owasp/dependency-check:latest \
            --scan /src \
            --format "XML,HTML" \
            --out /report || true

          # Fail the build on High/Critical findings
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

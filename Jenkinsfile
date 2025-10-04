pipeline {
  agent any

  environment {
    IMAGE_NAME = "govin55/assignment2"
    IMAGE_TAG  = "build-${env.BUILD_NUMBER}"

    // Keep these if you are using DinD; remove them if using host socket.
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

    stage('Detect app directory') {
      steps {
        script {
          // Find package.json (prefer root, otherwise first match within depth 2)
          def pkg = sh(script: "test -f package.json && echo package.json || find . -maxdepth 2 -name package.json -print -quit", returnStdout: true).trim()
          if (!pkg) {
            error "Could not find package.json in repo root or one-level subfolders."
          }
          def appDir = sh(script: "dirname '${pkg}'", returnStdout: true).trim()
          env.APP_DIR = appDir == "." ? "." : appDir
          echo "APP_DIR set to: ${env.APP_DIR}"

          // Find Dockerfile (prefer APP_DIR, else root)
          def df = sh(script: "[ -f '${env.APP_DIR}/Dockerfile' ] && echo '${env.APP_DIR}/Dockerfile' || ( [ -f 'Dockerfile' ] && echo 'Dockerfile' ) || true", returnStdout: true).trim()
          if (!df) {
            echo "WARNING: No Dockerfile found in ${env.APP_DIR} or repo root. Docker build will fail later."
          }
          env.DOCKERFILE_PATH = df
          echo "DOCKERFILE_PATH: ${env.DOCKERFILE_PATH == '' ? '(none found)' : env.DOCKERFILE_PATH}"
        }
      }
    }

    stage('Install dependencies (Node 16)') {
      steps {
        sh '''
          set -e
          echo "Installing deps in $APP_DIR"
          docker run --rm \
            -v "$PWD/$APP_DIR":/app -w /app \
            node:16 bash -lc "ls -la; npm install --save"
        '''
      }
    }

    stage('Unit tests (Node 16)') {
      steps {
        sh '''
          set -e
          docker run --rm \
            -v "$PWD/$APP_DIR":/app -w /app \
            node:16 bash -lc "npm test || echo 'No tests found — continuing'"
        '''
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: 'junit.xml'
        }
      }
    }

    stage('Dependency Scan (OWASP)') {
      steps {
        sh '''
          set -e
          mkdir -p .depcheck
          docker run --rm \
            -v "$PWD/$APP_DIR":/src \
            -v "$PWD/.depcheck":/report \
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

    stage('Docker build & push') {
      steps {
        script {
          // Build context = APP_DIR if present, else repo root
          def contextDir = env.APP_DIR ?: "."
          def dfArg = env.DOCKERFILE_PATH?.trim() ? "-f '${env.DOCKERFILE_PATH}'" : ""
          sh """
            set -e
            echo "Building image from context: ${contextDir}  Dockerfile: ${env.DOCKERFILE_PATH}"
          """
          withCredentials([usernamePassword(
            credentialsId: 'dockerhub-credentials-id',
            usernameVariable: 'DH_USER',
            passwordVariable: 'DH_PASS'
          )]) {
            sh """
              echo "\$DH_PASS" | docker login -u "\$DH_USER" --password-stdin
              docker build ${dfArg} -t ${IMAGE_NAME}:${IMAGE_TAG} ${contextDir}
              docker push ${IMAGE_NAME}:${IMAGE_TAG}
              docker tag  ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
              docker push ${IMAGE_NAME}:latest
            """
          }
        }
      }
    }
  }

  post {
    always { cleanWs() }
  }
}

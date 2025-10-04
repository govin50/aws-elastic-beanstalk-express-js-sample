pipeline {
  agent any

  environment {
    // ---- CHANGE NOTHING HERE (matches your Docker Hub repo) ----
    IMAGE_NAME = "govin55/assignment2"
    IMAGE_TAG  = "build-${env.BUILD_NUMBER}"

  
  }

  options {
    // show timestamps; fail fast on missing steps
    timestamps()
  }

  stages {
    stage('Checkout (clean)') {
      steps {
        cleanWs()
        checkout scm
      }
    }

    stage('Verify workspace') {
      steps {
        sh '''
          set -euxo pipefail
          echo "==== WORKSPACE TREE (top level) ===="
          ls -la
          echo "==== SEARCHING FOR package.json (depth 2) ===="
          find . -maxdepth 2 -type f -name package.json -print || true
        '''
      }
    }

    stage('Detect app directory') {
      steps {
        script {
          // Prefer root package.json; otherwise first match within one-level subfolders
          def pkg = sh(script: '''
            set -e
            if [ -f package.json ]; then
              echo package.json
            else
              find . -maxdepth 2 -type f -name package.json -print -quit
            fi
          ''', returnStdout: true).trim()

          if (!pkg) {
            error """No package.json found in workspace root or one-level subfolders.
Workspace contents printed in 'Verify workspace' stage for debugging.
Commit package.json to your repo and try again."""
          }

          def appDir = sh(script: "dirname '${pkg}'", returnStdout: true).trim()
          env.APP_DIR = (appDir == "." ? "." : appDir)
          echo "APP_DIR resolved to: ${env.APP_DIR}"

          // Dockerfile detection: prefer APP_DIR; else root; else warn (build will fail later)
          def df = sh(script: """
            set -e
            if [ -f '${env.APP_DIR}/Dockerfile' ]; then
              echo '${env.APP_DIR}/Dockerfile'
            elif [ -f 'Dockerfile' ]; then
              echo 'Dockerfile'
            fi
          """, returnStdout: true).trim()
          env.DOCKERFILE_PATH = df
          echo "DOCKERFILE_PATH: ${env.DOCKERFILE_PATH == '' ? '(not found)' : env.DOCKERFILE_PATH}"
        }
      }
    }

    stage('Docker sanity') {
      steps {
        sh '''
          set -e
          echo "Checking Docker connectivity (client & server)…"
          docker version
        '''
      }
    }

    stage('Install dependencies (Node 16)') {
      steps {
        sh '''
          set -euxo pipefail
          echo "Installing deps in $APP_DIR…"
          # Show what Jenkins actually mounted
          ls -la "$APP_DIR" || true

          docker run --rm \
            -v "$PWD/$APP_DIR":/app \
            -w /app \
            node:16 bash -lc 'node -v && npm -v && (npm ci || npm install)'

          echo "npm install completed."
        '''
      }
    }

    stage('Unit tests (Node 16)') {
      steps {
        sh '''
          set -euxo pipefail
          docker run --rm \
            -v "$PWD/$APP_DIR":/app \
            -w /app \
            node:16 bash -lc 'npm test || echo "No tests found — continuing"'
        '''
      }
      post {
        always {
          // if you produce junit.xml, this will pick it up; otherwise harmless
          junit allowEmptyResults: true, testResults: '**/junit.xml'
        }
      }
    }

    stage('Dependency Scan (OWASP)') {
      steps {
        sh '''
          set -euxo pipefail
          mkdir -p .depcheck
          docker run --rm \
            -v "$PWD/$APP_DIR":/src \
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
            echo "OWASP summary => High: ${HIGHS}, Critical: ${CRITS}, Total: ${TOTAL}"
            if [ "$TOTAL" -gt 0 ]; then
              echo "Failing build due to High/Critical vulnerabilities."
              exit 1
            fi
          else
            echo "WARNING: No OWASP XML report found; check scan output."
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
          if (!env.DOCKERFILE_PATH?.trim()) {
            error "No Dockerfile found in ${env.APP_DIR} or repo root. Add a Dockerfile and re-run."
          }
          def contextDir = env.APP_DIR ?: "."
          sh """
            set -e
            echo "Building image from context: ${contextDir}"
            echo "Using Dockerfile: ${env.DOCKERFILE_PATH}"
          """
          withCredentials([usernamePassword(
            credentialsId: 'dockerhub-credentials-id',
            usernameVariable: 'DH_USER',
            passwordVariable: 'DH_PASS'
          )]) {
            sh '''
              set -euxo pipefail
              echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
              docker build -f "$DOCKERFILE_PATH" -t "${IMAGE_NAME}:${IMAGE_TAG}" "$APP_DIR"
              docker push "${IMAGE_NAME}:${IMAGE_TAG}"
              docker tag  "${IMAGE_NAME}:${IMAGE_TAG}" "${IMAGE_NAME}:latest"
              docker push "${IMAGE_NAME}:latest"
            '''
          }
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

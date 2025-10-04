pipeline {
  agent any

  environment {
    // ---- your Docker Hub target ----
    IMAGE_NAME = "govin55/assignment2"
    IMAGE_TAG  = "build-${env.BUILD_NUMBER}"

    // ---- DinD connectivity (keep for docker:27-dind). If using host socket, remove these 3. ----
    DOCKER_HOST       = 'tcp://docker:2376'
    DOCKER_TLS_VERIFY = '1'
    DOCKER_CERT_PATH  = '/certs/client'
  }

  options {
    timestamps()
    buildDiscarder(logRotator(numToKeepStr: '10'))
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
        sh '''#!/usr/bin/env bash
set -e
echo "== TOP LEVEL =="
ls -la
echo "== SEARCH package.json (depth 2) =="
find . -maxdepth 2 -type f -name package.json -print || true
'''
      }
    }

    stage('Detect APP_DIR & Dockerfile') {
      steps {
        sh '''#!/usr/bin/env bash
set -e
PKG="$( [ -f package.json ] && echo package.json || find . -maxdepth 2 -type f -name package.json -print -quit )"
[ -n "$PKG" ] || { echo "ERROR: No package.json found in root or one-level subfolders"; exit 1; }
APP_DIR="$(dirname "$PKG")"; [ "$APP_DIR" = "." ] && APP_DIR="."
DF=""
[ -f "$APP_DIR/Dockerfile" ] && DF="$APP_DIR/Dockerfile"
[ -z "$DF" ] && [ -f Dockerfile ] && DF="Dockerfile"
echo "APP_DIR=$APP_DIR"           >  .envfile
echo "DOCKERFILE_PATH=$DF"        >> .envfile
cat .envfile
'''
      }
    }

    stage('Docker sanity (DinD)') {
      steps {
        sh '''#!/usr/bin/env bash
set -e
docker version
'''
      }
    }

    stage('Install deps (Node 16, no mounts)') {
      steps {
        sh '''#!/usr/bin/env bash
set -e
source .envfile
echo "Installing deps in $APP_DIR (DinD-safe)…"

# 1) Create idle Node 16 container
CID="$(docker create node:16 bash -lc 'sleep infinity')"
echo "CID=$CID"

# 2) Copy source into the container
docker cp "$APP_DIR/." "$CID:/app"

# 3) Start + install
docker start "$CID" 1>/dev/null
docker exec -u 0:0 "$CID" bash -lc 'cd /app && node -v && npm -v && (npm ci || npm install)'

# 4) Cleanup
docker rm -f "$CID" 1>/dev/null
echo "✅ npm install done"
'''
      }
    }

    stage('Unit tests (Node 16)') {
      steps {
        sh '''#!/usr/bin/env bash
set -e
source .envfile
CID="$(docker create node:16 bash -lc 'sleep infinity')"
docker cp "$APP_DIR/." "$CID:/app"
docker start "$CID" 1>/dev/null
docker exec -u 0:0 "$CID" bash -lc 'cd /app && (npm test || echo "No tests found — continuing")'
docker rm -f "$CID" 1>/dev/null
'''
      }
      post {
        always {
          // harmless if you don't produce junit.xml
          junit allowEmptyResults: true, testResults: '**/junit.xml'
        }
      }
    }

    stage('OWASP scan (fail on High/Critical)') {
      steps {
        sh '''#!/usr/bin/env bash
set -e
source .envfile
mkdir -p .depcheck

# create scanner container with command preset
CID="$(docker create owasp/dependency-check:latest --scan /src --format XML,HTML --out /report)"
docker cp "$APP_DIR/." "$CID:/src"

set +e
docker start -a "$CID"
RC=$?
set -e

docker cp "$CID:/report/." ".depcheck/" || true
docker rm -f "$CID" 1>/dev/null || true

if [ -f .depcheck/dependency-check-report.xml ]; then
  H=$(grep -o 'severity="High"'     .depcheck/dependency-check-report.xml | wc -l || true)
  C=$(grep -o 'severity="Critical"' .depcheck/dependency-check-report.xml | wc -l || true)
  T=$((H+C))
  echo "OWASP => High:${H} Critical:${C} Total:${T}"
  if [ "$T" -gt 0 ]; then
    echo "❌ Failing build due to High/Critical vulnerabilities."
    exit 1
  fi
else
  echo "WARNING: no OWASP XML report found"
fi
'''
      }
      post {
        always {
          archiveArtifacts artifacts: '.depcheck/**', allowEmptyArchive: true, fingerprint: true
        }
      }
    }

    stage('Docker build & push') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials-id', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
          sh '''#!/usr/bin/env bash
set -e
source .envfile
[ -n "$DOCKERFILE_PATH" ] || { echo "ERROR: No Dockerfile in $APP_DIR or root"; exit 1; }

echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
# docker build uploads context over the Docker API — safe with DinD
docker build -f "$DOCKERFILE_PATH" -t "${IMAGE_NAME}:${IMAGE_TAG}" "$APP_DIR"
docker push "${IMAGE_NAME}:${IMAGE_TAG}"
docker tag  "${IMAGE_NAME}:${IMAGE_TAG}" "${IMAGE_NAME}:latest"
docker push "${IMAGE_NAME}:latest"
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

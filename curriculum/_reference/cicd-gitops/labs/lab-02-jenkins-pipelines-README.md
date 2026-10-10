# Lab 02: Jenkins Pipeline Development

## Overview

In this lab, you'll master Jenkins Pipeline development using both Declarative and Scripted syntax. You'll build complex pipelines, implement shared libraries, and configure Jenkins using Configuration as Code.

**Duration**: 3-4 hours
**Difficulty**: Intermediate

## Prerequisites

- Docker and Docker Compose installed
- Git configured
- Basic understanding of CI/CD concepts
- Familiarity with Groovy syntax (helpful)

## Learning Objectives

- Create Declarative and Scripted Pipelines
- Implement parallel stages and matrix builds
- Build and use Shared Libraries
- Configure Jenkins as Code (JCasC)
- Set up distributed builds with agents

## Lab Environment Setup

```bash
# Create lab directory
mkdir -p ~/jenkins-lab && cd ~/jenkins-lab

# Create Docker Compose for Jenkins
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  jenkins:
    image: jenkins/jenkins:lts-jdk17
    container_name: jenkins
    privileged: true
    user: root
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - JAVA_OPTS=-Djenkins.install.runSetupWizard=false
    networks:
      - jenkins-net

  jenkins-agent:
    image: jenkins/inbound-agent:latest
    container_name: jenkins-agent
    depends_on:
      - jenkins
    environment:
      - JENKINS_URL=http://jenkins:8080
      - JENKINS_AGENT_NAME=docker-agent
      - JENKINS_SECRET=${AGENT_SECRET:-}
      - JENKINS_AGENT_WORKDIR=/home/jenkins/agent
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - jenkins-net

volumes:
  jenkins_home:

networks:
  jenkins-net:
    driver: bridge
EOF

# Start Jenkins
docker-compose up -d

# Wait for Jenkins to start
echo "Waiting for Jenkins to start..."
until curl -s http://localhost:8080/login > /dev/null 2>&1; do
  sleep 5
done

# Get initial admin password
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

---

## Part 1: Guided Exercise - Declarative Pipeline Fundamentals

### Step 1: Create a Sample Application

```bash
# Create application directory
mkdir -p sample-app && cd sample-app

# Initialize Git repository
git init

# Create a simple Python application
cat > app.py << 'EOF'
from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/')
def hello():
    return jsonify({
        "message": "Hello from Jenkins Pipeline!",
        "version": os.getenv("APP_VERSION", "1.0.0")
    })

@app.route('/health')
def health():
    return jsonify({"status": "healthy"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

# Create tests
cat > test_app.py << 'EOF'
import pytest
from app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_hello(client):
    response = client.get('/')
    assert response.status_code == 200
    assert b"Hello from Jenkins Pipeline!" in response.data

def test_health(client):
    response = client.get('/health')
    assert response.status_code == 200
    assert b"healthy" in response.data
EOF

# Create requirements
cat > requirements.txt << 'EOF'
flask==3.0.0
pytest==7.4.3
pytest-cov==4.1.0
EOF

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 5000

CMD ["python", "app.py"]
EOF
```

### Step 2: Create Basic Declarative Pipeline

```bash
# Create Jenkinsfile
cat > Jenkinsfile << 'EOF'
pipeline {
    agent any

    environment {
        APP_NAME = 'sample-app'
        DOCKER_REGISTRY = 'localhost:5000'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()
                }
            }
        }

        stage('Install Dependencies') {
            steps {
                sh '''
                    python -m venv venv
                    . venv/bin/activate
                    pip install -r requirements.txt
                '''
            }
        }

        stage('Lint') {
            steps {
                sh '''
                    . venv/bin/activate
                    pip install flake8
                    flake8 app.py --max-line-length=120
                '''
            }
        }

        stage('Test') {
            steps {
                sh '''
                    . venv/bin/activate
                    pytest test_app.py -v --junitxml=test-results.xml --cov=app --cov-report=xml
                '''
            }
            post {
                always {
                    junit 'test-results.xml'
                    publishCoverage adapters: [coberturaAdapter('coverage.xml')]
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    docker.build("${APP_NAME}:${GIT_COMMIT_SHORT}")
                }
            }
        }

        stage('Security Scan') {
            steps {
                sh '''
                    # Run Trivy scan
                    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                        aquasec/trivy:latest image --severity HIGH,CRITICAL \
                        ${APP_NAME}:${GIT_COMMIT_SHORT} || true
                '''
            }
        }

        stage('Deploy to Staging') {
            when {
                branch 'develop'
            }
            steps {
                echo "Deploying to staging environment..."
                sh '''
                    docker stop ${APP_NAME}-staging || true
                    docker rm ${APP_NAME}-staging || true
                    docker run -d --name ${APP_NAME}-staging \
                        -p 5001:5000 ${APP_NAME}:${GIT_COMMIT_SHORT}
                '''
            }
        }

        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            input {
                message "Deploy to production?"
                ok "Deploy"
                parameters {
                    string(name: 'DEPLOY_VERSION', defaultValue: '', description: 'Version to deploy')
                }
            }
            steps {
                echo "Deploying to production..."
                sh '''
                    docker stop ${APP_NAME}-prod || true
                    docker rm ${APP_NAME}-prod || true
                    docker run -d --name ${APP_NAME}-prod \
                        -p 5000:5000 ${APP_NAME}:${GIT_COMMIT_SHORT}
                '''
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully!'
            // slackSend channel: '#deployments', color: 'good', message: "Build Successful: ${env.JOB_NAME} ${env.BUILD_NUMBER}"
        }
        failure {
            echo 'Pipeline failed!'
            // slackSend channel: '#deployments', color: 'danger', message: "Build Failed: ${env.JOB_NAME} ${env.BUILD_NUMBER}"
        }
        always {
            cleanWs()
        }
    }
}
EOF
```

### Step 3: Create Pipeline with Parallel Stages

```bash
# Create advanced Jenkinsfile with parallelism
cat > Jenkinsfile.parallel << 'EOF'
pipeline {
    agent any

    stages {
        stage('Build and Test') {
            parallel {
                stage('Unit Tests') {
                    agent {
                        docker {
                            image 'python:3.11-slim'
                            args '-v $HOME/.cache/pip:/root/.cache/pip'
                        }
                    }
                    steps {
                        sh '''
                            pip install -r requirements.txt
                            pytest test_app.py -v --junitxml=unit-results.xml
                        '''
                    }
                    post {
                        always {
                            junit 'unit-results.xml'
                        }
                    }
                }

                stage('Integration Tests') {
                    agent {
                        docker {
                            image 'python:3.11-slim'
                        }
                    }
                    steps {
                        sh '''
                            pip install -r requirements.txt
                            # Run integration tests
                            echo "Running integration tests..."
                        '''
                    }
                }

                stage('Security Scan') {
                    steps {
                        sh '''
                            echo "Running security scan..."
                            # pip-audit or safety scan
                        '''
                    }
                }

                stage('Lint') {
                    agent {
                        docker {
                            image 'python:3.11-slim'
                        }
                    }
                    steps {
                        sh '''
                            pip install flake8 black
                            flake8 app.py
                            black --check app.py
                        '''
                    }
                }
            }
        }

        stage('Build') {
            steps {
                script {
                    docker.build("sample-app:${env.BUILD_NUMBER}")
                }
            }
        }
    }
}
EOF
```

### Step 4: Create Matrix Build Pipeline

```bash
# Create Jenkinsfile with matrix
cat > Jenkinsfile.matrix << 'EOF'
pipeline {
    agent none

    stages {
        stage('Test Matrix') {
            matrix {
                axes {
                    axis {
                        name 'PYTHON_VERSION'
                        values '3.9', '3.10', '3.11'
                    }
                    axis {
                        name 'OS'
                        values 'linux', 'windows'
                    }
                }
                excludes {
                    exclude {
                        axis {
                            name 'OS'
                            values 'windows'
                        }
                        axis {
                            name 'PYTHON_VERSION'
                            values '3.9'
                        }
                    }
                }
                stages {
                    stage('Test') {
                        agent {
                            docker {
                                image "python:${PYTHON_VERSION}-slim"
                            }
                        }
                        steps {
                            echo "Testing on Python ${PYTHON_VERSION} / ${OS}"
                            sh '''
                                pip install pytest flask
                                pytest test_app.py -v
                            '''
                        }
                    }
                }
            }
        }
    }
}
EOF
```

---

## Part 2: Semi-Guided Exercise - Shared Libraries

### Objective

Create a Jenkins Shared Library with reusable pipeline components:
- Build steps
- Deployment functions
- Notification helpers
- Utility functions

### Requirements

1. **Create shared library structure**

<details>
<summary>Click for directory structure hint</summary>

**`jenkins-shared-library/`**

- `vars/`
  - `buildPipeline.groovy`
  - `deployApp.groovy`
  - `notify.groovy`
- `src/`
  - `org/`
    - `example/`
      - `Utils.groovy`
- `resources/`
  - `templates/`
    - `deployment.yaml`

</details>

2. **Implement global variables**

<details>
<summary>Click for buildPipeline.groovy hint</summary>

```groovy
def call(Map config = [:]) {
    pipeline {
        agent any

        stages {
            stage('Build') {
                steps {
                    script {
                        if (config.language == 'python') {
                            sh 'pip install -r requirements.txt'
                        } else if (config.language == 'node') {
                            sh 'npm ci'
                        }
                    }
                }
            }
            // Add more stages
        }
    }
}
```
</details>

3. **Configure library in Jenkins**

<details>
<summary>Click for configuration hint</summary>

```groovy
// In Jenkinsfile
@Library('my-shared-library@main') _

buildPipeline(
    language: 'python',
    testCommand: 'pytest',
    deployTarget: 'kubernetes'
)
```
</details>

### Tasks

1. Create a shared library with the following components:
   - `buildPipeline.groovy` - Complete CI/CD pipeline
   - `dockerBuild.groovy` - Docker build and push
   - `kubernetesDeplooy.groovy` - K8s deployment
   - `notify.groovy` - Slack/Email notifications

2. Add utility class in `src/org/example/Utils.groovy`

3. Configure the library in Jenkins

4. Create a pipeline that uses the shared library

### Validation

```bash
# Create test pipeline using shared library
cat > Jenkinsfile.shared << 'EOF'
@Library('my-shared-library@main') _

buildPipeline(
    appName: 'my-app',
    language: 'python',
    dockerRegistry: 'ghcr.io/myorg',
    kubernetesNamespace: 'production',
    slackChannel: '#deployments'
)
EOF

# Verify library functions are available
# Check Jenkins console output for proper execution
```

---

## Part 3: Challenge - Jenkins Configuration as Code

### Objective

Implement complete Jenkins automation using:
- Configuration as Code (JCasC)
- Job DSL for pipeline generation
- Automated plugin management
- Backup and restore strategy

### Requirements

1. **Create JCasC configuration**

```yaml
# jenkins.yaml
jenkins:
  systemMessage: "Jenkins configured via JCasC"
  numExecutors: 2
  mode: NORMAL

  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: admin
          name: "Administrator"
          password: ${ADMIN_PASSWORD}

  authorizationStrategy:
    roleBased:
      roles:
        global:
          - name: "admin"
            permissions:
              - "Overall/Administer"
            entries:
              - user: "admin"
          - name: "developer"
            permissions:
              - "Overall/Read"
              - "Job/Build"
              - "Job/Read"
            entries:
              - group: "developers"

  clouds:
    - kubernetes:
        name: "kubernetes"
        serverUrl: "https://kubernetes.default"
        namespace: "jenkins"
        jenkinsUrl: "http://jenkins:8080"
        templates:
          - name: "default"
            label: "jenkins-agent"
            containers:
              - name: "jnlp"
                image: "jenkins/inbound-agent:latest"
                workingDir: "/home/jenkins/agent"

unclassified:
  location:
    url: "http://jenkins.example.com/"
    adminAddress: "admin@example.com"

  gitHubPluginConfig:
    configs:
      - name: "GitHub"
        apiUrl: "https://api.github.com"
        credentialsId: "github-token"

credentials:
  system:
    domainCredentials:
      - credentials:
          - string:
              scope: GLOBAL
              id: "github-token"
              secret: ${GITHUB_TOKEN}
          - usernamePassword:
              scope: GLOBAL
              id: "docker-registry"
              username: ${DOCKER_USER}
              password: ${DOCKER_PASSWORD}
```

2. **Create Job DSL seed job**

3. **Implement backup strategy**

4. **Create Docker image with all configurations**

### Success Criteria

- [ ] Jenkins starts with complete configuration
- [ ] All plugins installed automatically
- [ ] Users and roles configured
- [ ] Kubernetes cloud configured
- [ ] Seed job creates all pipelines
- [ ] Backup runs daily
- [ ] Configuration is version controlled

### Starting Point

```bash
# Create Jenkins Docker image with JCasC
cat > Dockerfile.jenkins << 'EOF'
FROM jenkins/jenkins:lts-jdk17

# Skip setup wizard
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc.yaml

# Install plugins
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Copy JCasC configuration
COPY jenkins.yaml /var/jenkins_home/casc.yaml

USER jenkins
EOF

# Create plugins list
cat > plugins.txt << 'EOF'
configuration-as-code
job-dsl
kubernetes
github-branch-source
pipeline-stage-view
blueocean
role-strategy
credentials
git
docker-workflow
EOF
```

### Validation Script

```bash
#!/bin/bash
# validate-jenkins.sh

echo "Validating Jenkins Configuration..."

JENKINS_URL="http://localhost:8080"

# Check Jenkins is running
if curl -s "$JENKINS_URL/login" > /dev/null; then
    echo "✓ Jenkins is accessible"
else
    echo "✗ Jenkins is not accessible"
    exit 1
fi

# Check JCasC status
if curl -s "$JENKINS_URL/configuration-as-code/" > /dev/null; then
    echo "✓ JCasC plugin active"
else
    echo "✗ JCasC plugin not found"
fi

# Check required plugins
for plugin in kubernetes github-branch-source blueocean; do
    if curl -s "$JENKINS_URL/pluginManager/api/json?depth=1" | grep -q "\"shortName\":\"$plugin\""; then
        echo "✓ Plugin '$plugin' installed"
    else
        echo "✗ Plugin '$plugin' missing"
    fi
done

# Check jobs exist
JOBS=$(curl -s "$JENKINS_URL/api/json" | jq '.jobs | length')
echo "✓ Found $JOBS jobs"

echo "Validation complete!"
```

---

## Cleanup

```bash
# Stop and remove containers
docker-compose down -v

# Remove lab files
cd ~
rm -rf jenkins-lab
```

## Summary

In this lab, you learned:
- Creating Declarative and Scripted Pipelines
- Implementing parallel stages and matrix builds
- Building reusable Shared Libraries
- Configuring Jenkins as Code (JCasC)
- Setting up distributed builds with Kubernetes

## Next Steps

- Explore Jenkins X for cloud-native CI/CD
- Implement Jenkinsfile validation with replay
- Set up Jenkins High Availability
- Integrate with HashiCorp Vault for secrets

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Challenge - Jenkins Configuration as Code
- Create a Sample Application
- Create Basic Declarative Pipeline
- Create Pipeline with Parallel Stages

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The pipeline deploys the application."* |
| ✓ | *"CI writes a new image tag into a config repository and stops. A controller running *inside* the cluster polls that repo, diffs the rendered manifests against live state, and applies the difference — so nothing outside the cluster ever holds credentials to it."* |

**Trace it:** `git push` → the new version serving traffic, with nothing else typed. Name where the handoff between CI and CD happens, and what that handoff physically is.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the four [OpenGitOps principles](https://opengitops.dev/#principles) — then say which one a `kubectl apply` inside CI violates.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#cicd-gitops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->

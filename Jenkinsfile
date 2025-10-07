pipeline {
  agent {
    node {
      label 'jenkins-agent'
    }
  }

  options {
    disableConcurrentBuilds()
    skipDefaultCheckout()
    buildDiscarder(logRotator(
      daysToKeepStr: '3',
      numToKeepStr: '5',
      artifactDaysToKeepStr: '3',
      artifactNumToKeepStr: '5'))
  }

  triggers {
    githubPush()
  }

  environment {
    REPO_NAME = "devsecops"
    REPO_USER = "Rullabcde"
    IMAGE_NAME = "reg.rullabcd.my.id/library/app"
    IMAGE_TAG = "${env.BUILD_NUMBER}"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Code Scan') {
      agent {
        docker {
          image 'sonarsource/sonar-scanner-cli:latest'
          reuseNode true
        }
      }
      steps {
        withCredentials([
          string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN'),
          string(credentialsId: 'sonar-host', variable: 'SONAR_HOST')
        ]) {
          sh '''
            export SONAR_USER_HOME=$WORKSPACE/.sonar
            mkdir -p $SONAR_USER_HOME

            sonar-scanner \
              -Dsonar.projectKey=App \
              -Dsonar.sources=. \
              -Dsonar.exclusions=**/node_modules/**,**/test/** \
              -Dsonar.host.url=$SONAR_HOST \
              -Dsonar.token=$SONAR_TOKEN
          '''
        }
      }
    }

    stage('Build Docker Image') {
      steps {
        sh '''
          docker build --target runner -t ${IMAGE_NAME}:${IMAGE_TAG} -f applications/Dockerfile applications
          docker build --target migrator -t ${IMAGE_NAME}-migrator:${IMAGE_TAG} -f applications/Dockerfile applications
        '''
      }
    }

    stage('Vulnerability Scan') {
      steps {
        sh '''
          trivy image --severity HIGH,CRITICAL --exit-code 0 --no-progress ${IMAGE_NAME}:${IMAGE_TAG}
          trivy image --severity HIGH,CRITICAL --exit-code 0 --no-progress ${IMAGE_NAME}-migrator:${IMAGE_TAG}
        '''
      }
    }

    stage('Push to Registry') {
      steps {
        withCredentials([
          usernamePassword(
            credentialsId: 'harbor-credentials', 
            usernameVariable: 'HARBOR_USER', 
            passwordVariable: 'HARBOR_PASS')]) 
          {
            sh '''
              echo $HARBOR_PASS | docker login reg.rullabcd.my.id -u $HARBOR_USER --password-stdin
            '''
        }
        sh '''
          docker push ${IMAGE_NAME}:${IMAGE_TAG}
          docker push ${IMAGE_NAME}-migrator:${IMAGE_TAG}
        '''
      }
    }

    stage('Update Manifests') {
      steps {
        withCredentials([
          string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')
        ]) {
          sh '''
            git config user.email "choirulrasyid09@gmail.com"
            git config user.name "Rullabcde"
            git checkout main
            
            sed -i "s|__IMAGE_TAG__|${IMAGE_TAG}|g" manifests/deployment.yml
            sed -i "s|__IMAGE_TAG__|${IMAGE_TAG}|g" manifests/job.yml

            git add manifests/deployment.yml
            git add manifests/job.yml
            git commit -m "Update deployment image tag to ${IMAGE_TAG}"

            git push https://${GITHUB_TOKEN}@github.com/${REPO_USER}/${REPO_NAME}.git HEAD:main
          '''
        }
      }
    }

  }

  post {
    always {
      cleanWs()
      sh 'docker logout reg.rullabcd.my.id || true'
    }
    success {
      echo "Build and push of ${IMAGE_NAME}:${IMAGE_TAG} succeeded"
      // slackSend(channel: '#jenkins', color: 'good', message: "Build and push of ${IMAGE_NAME}:${IMAGE_TAG} succeeded")
    }
    failure {
      echo "Build and push of ${IMAGE_NAME}:${IMAGE_TAG} failed"
      // slackSend(channel: '#jenkins', color: 'danger', message: "Build and push of ${IMAGE_NAME}:${IMAGE_TAG} failed")
    }
  }
}

pipeline{
  agent any

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
    IMAGE_NAME = 'rullabcd/app'
    IMAGE_TAG = "${env.BUILD_NUMBER}"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Build Docker Image') {
      steps {
        sh '''
          docker build --target runner -t ${IMAGE_NAME}:${IMAGE_TAG} .
          docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
          docker build --target migrator -t ${IMAGE_NAME}-migrator:${IMAGE_TAG} .
          docker tag ${IMAGE_NAME}-migrator:${IMAGE_TAG} ${IMAGE_NAME}-migrator:latest

        '''
      }
    }

    stage('Push Docker Image') { 
      steps {
        withCredentials([
          usernamePassword(
            credentialsId: 'docker-credentials', 
            usernameVariable: 'DOCKER_USERNAME', 
            passwordVariable: 'DOCKER_PASSWORD')]) {
              sh '''
                echo $DOCKER_PASSWORD | docker login -u $DOCKER_USERNAME --password-stdin
                docker push ${IMAGE_NAME}:${IMAGE_TAG}
                docker push ${IMAGE_NAME}:latest
                docker push ${IMAGE_NAME}-migrator:${IMAGE_TAG}
                docker push ${IMAGE_NAME}-migrator:latest
              '''
            }
      }
    }

    stage('Deploy to STG') {
      when { branch 'stg' }
      steps {
        withCredentials([
          string(credentialsId: 'ip-vps', variable: 'VPS_IP'),
          string(credentialsId: 'port-vps', variable: 'VPS_PORT'),
          sshUserPrivateKey(
            credentialsId: 'ssh-vps', 
            keyFileVariable: 'SSH_KEY', 
            usernameVariable: 'SSH_USER')]) {
              sh '''
                ssh -o StrictHostKeyChecking=no -i $SSH_KEY_PATH $SSH_USER@$VPS_IP -p $VPS_PORT << EOF
                  cd ~/app
                  ./deploy-stg.sh
                EOF
              '''
            }
      }
    }

    stage('Deploy to PROD') {
      when { branch 'prod' }
      steps {
        withCredentials([
          string(credentialsId: 'ip-vps', variable: 'VPS_IP'),
          string(credentialsId: 'port-vps', variable: 'VPS_PORT'),
          sshUserPrivateKey(
            credentialsId: 'ssh-vps', 
            keyFileVariable: 'SSH_KEY', 
            usernameVariable: 'SSH_USER')]) {
              sh '''
                ssh -o StrictHostKeyChecking=no -i $SSH_KEY_PATH $SSH_USER@$VPS_IP -p $VPS_PORT << EOF
                  cd ~/app
                  ./deploy-prod.sh
                EOF
              '''
            }
      }
    }
  }

  post {
      always {
        cleanWs()
        sh 'docker logout || true'
      }
      success {
        echo 'Build and deployment succeeded!'
      }
      failure {
        echo 'Build or deployment failed.'
    }
  }
}
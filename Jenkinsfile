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
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Tag Image') {
      steps {
        script {
          def lastSuccessfulBuild = currentBuild.previousSuccessfulBuild?.number ?: 0
          def version = lastSuccess + 1
          env.IMAGE_TAG = "v1.0.${version}"
        }
      }
    }

    stage('Build Docker Image') {
      steps {
        sh '''
          docker build --target runner -t ${IMAGE_NAME}:${env.IMAGE_TAG} .
          docker tag ${IMAGE_NAME}:${env.IMAGE_TAG} ${IMAGE_NAME}:latest
          docker build --target migrator -t ${IMAGE_NAME}-migrator:${env.IMAGE_TAG} .
          docker tag ${IMAGE_NAME}-migrator:${env.IMAGE_TAG} ${IMAGE_NAME}-migrator:latest

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
                docker push ${IMAGE_NAME}:${env.IMAGE_TAG}
                docker push ${IMAGE_NAME}:latest
                docker push ${IMAGE_NAME}-migrator:${env.IMAGE_TAG}
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
                ssh -o StrictHostKeyChecking=no -i $SSH_KEY $SSH_USER@$VPS_IP -p $VPS_PORT "
                  cd ~/app
                  ./deploy-stg.sh
                "
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
                ssh -o StrictHostKeyChecking=no -i $SSH_KEY $SSH_USER@$VPS_IP -p $VPS_PORT "
                  cd ~/app
                  ./deploy-prod.sh
                "
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
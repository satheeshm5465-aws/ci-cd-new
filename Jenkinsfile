pipeline {
  agent any

  options { timestamps() }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Build Docker Image') {
      steps {
        sh 'docker build --no-cache -t myapp:latest .'
      }
    }

    stage('Deploy (Blue/Green)') {
      steps {
        sh '''
          chmod +x deploy.sh
          ./deploy.sh
        '''
      }
    }

    stage('Cleanup') {
      steps {
        sh 'docker image prune -f || true'
      }
    }
  }
}

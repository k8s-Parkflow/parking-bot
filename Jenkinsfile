pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug
    command:
    - sleep
    args:
    - 999d
    volumeMounts:
    - name: kaniko-secret
      mountPath: /kaniko/.docker
  volumes:
  - name: kaniko-secret
    secret:
      secretName: dockerhub-secret
      items:
        - key: .dockerconfigjson
          path: config.json
"""
        }
    }

    environment {
        // 도커 허브 이미지 (봇 전용 레포지토리)
        DOCKER_IMAGE = "hyungdongjo/parking-bot"
        DEPLOY_REPO_URL = "https://github.com/k8s-Parkflow/Deploy.git"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build and Push Bot Image') {
            steps {
                container('kaniko') {
                    sh """
                    /kaniko/executor \
                      --context "${env.WORKSPACE}" \
                      --dockerfile Dockerfile \
                      --destination ${DOCKER_IMAGE}:v${env.BUILD_NUMBER} \
                      --destination ${DOCKER_IMAGE}:latest
                    """
                }
            }
        }

        stage('Update Bot Manifest') {
            steps {
                script {
                    sh "rm -rf deploy-repo"
                    
                    withCredentials([usernamePassword(credentialsId: 'github-token', passwordVariable: 'GIT_TOKEN', usernameVariable: 'GIT_USER')]) {
                        dir('deploy-repo') {
                            git credentialsId: 'github-token', 
                                url: "${env.DEPLOY_REPO_URL}",
                                branch: 'main'
                            
                            // 봇 전용 매니페스트 파일 경로 (아래 '필독' 참고)
                            def botManifest = "parking-bot/parking-bot-deployment.yaml"
                            
                            if (fileExists(botManifest)) {
                                sh "sed -i 's|image: ${DOCKER_IMAGE}:.*|image: ${DOCKER_IMAGE}:v${env.BUILD_NUMBER}|g' ${botManifest}"
                                
                                sh """
                                    git config user.email "jenkins-bot@parkflow.local"
                                    git config user.name "Jenkins-CI-Bot"
                                    git add .
                                    git commit -m "Deploy: parking-bot v${env.BUILD_NUMBER} [skip ci]"
                                    git remote set-url origin https://${GIT_USER}:${GIT_TOKEN}@github.com/k8s-Parkflow/Deploy.git
                                    git push origin main
                                """
                                echo "✅ 봇 매니페스트 업데이트 완료!"
                            } else {
                                error "❌ ${botManifest} 파일을 찾을 수 없습니다. Deploy 레포에 파일을 먼저 생성해주세요!"
                            }
                        }
                    }
                }
            }
        }
    }

    post {
        success {
            echo "🎉 봇 빌드 및 배포 자동화 성공!"
        }
    }
}

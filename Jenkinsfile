pipeline {
    agent {
        kubernetes {
            // Kaniko 빌드를 위한 전용 포드 템플릿
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
        // 1. 봇 전용 이미지 이름으로 변경
        DOCKER_IMAGE = "hyungdongjo/parking-bot"
    }

    stages {
        stage('Checkout') {
            steps {
                // parking-bot 소스 코드를 가져옵니다.
                checkout scm
            }
        }

        stage('Build and Push Image') {
            steps {
                container('kaniko') {
                    // Kaniko를 이용해 봇 이미지를 빌드하고 푸시합니다.
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

        stage('Update Manifest') {
            steps {
                script {
                    sh "rm -rf deploy-repo"
                    
                    // github-token 자격 증명을 사용하여 Deploy 레포 업데이트
                    withCredentials([usernamePassword(credentialsId: 'github-token', passwordVariable: 'GIT_TOKEN', usernameVariable: 'GIT_USER')]) {
                        dir('deploy-repo') {
                            git credentialsId: 'github-token', 
                                url: 'https://github.com/k8s-Parkflow/Deploy.git',
                                branch: 'main'
                            
                            // 2. 봇의 매니페스트 파일 경로 (Deploy 레포지토리 내의 경로)
                            def botManifest = "parking-bot/parking-bot-deployment.yaml"
                            
                            if (fileExists(botManifest)) {
                                // sed 명령어로 이미지 태그만 쏙 바꿉니다.
                                sh "sed -i 's|image: ${DOCKER_IMAGE}:.*|image: ${DOCKER_IMAGE}:v${env.BUILD_NUMBER}|g' ${botManifest}"
                                
                                sh """
                                    git config user.email "jenkins-bot@parkflow.local"
                                    git config user.name "Jenkins-CI-Bot"
                                    git add .
                                    # 변경사항이 있을 때만 커밋 (skip ci 포함)
                                    git diff --quiet && git diff --staged --quiet || git commit -m "Deploy: parking-bot v${env.BUILD_NUMBER} [skip ci]"
                                    
                                    # 인증 정보를 포함하여 푸시
                                    git remote set-url origin https://${GIT_USER}:${GIT_TOKEN}@github.com/k8s-Parkflow/Deploy.git
                                    git push origin main
                                """
                                echo "✅ parking-bot 매니페스트 업데이트 성공!"
                            } else {
                                error "❌ ${botManifest} 파일을 찾을 수 없습니다. Deploy 레포에 파일을 먼저 만들어주세요!"
                            }
                        }
                    }
                }
            }
        }
    }

    post {
        success {
            echo "🎉 성공: parking-bot 이미지가 푸시되었고 매니페스트가 v${env.BUILD_NUMBER}로 업데이트되었습니다!"
        }
        failure {
            echo "❌ 실패: 파이프라인 실행 중 에러가 발생했습니다. 로그를 확인하세요."
        }
    }
}

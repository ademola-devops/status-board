pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
    }

    environment {
        BACKEND_IMAGE  = 'ademoladevops/status-backend'
        FRONTEND_IMAGE = 'ademoladevops/status-frontend'
    }

    triggers {
        githubPush()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    // Tag every image with the commit it was built from
                    env.TAG = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
                }
                echo "Building version ${env.TAG}"
            }
        }

        stage('Build Images') {
            steps {
                sh 'docker build -t $BACKEND_IMAGE:$TAG backend'
                sh 'docker build -t $FRONTEND_IMAGE:$TAG frontend'
            }
        }

        stage('Push to DockerHub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds',
                                                  usernameVariable: 'DH_USER',
                                                  passwordVariable: 'DH_PASS')]) {
                    sh 'echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin'
                    sh 'docker push $BACKEND_IMAGE:$TAG'
                    sh 'docker push $FRONTEND_IMAGE:$TAG'
                }
            }
        }

        stage('Deploy to Staging') {
            steps {
                sh 'chmod +x scripts/*.sh'
                sh './scripts/deploy.sh staging $TAG'
            }
        }

        stage('Smoke Test Staging') {
            steps {
                sh './scripts/smoke-test.sh staging $TAG'
            }
        }

        stage('Approve Release') {
            steps {
                timeout(time: 30, unit: 'MINUTES') {
                    input message: "Staging passed for ${env.TAG}. Promote to production?",
                          ok: 'Promote'
                }
            }
        }

        stage('Deploy to Production') {
            steps {
                // Same image that passed staging, no rebuild
                sh './scripts/deploy.sh production $TAG'
            }
        }

        stage('Smoke Test Production') {
            steps {
                script {
                    try {
                        sh './scripts/smoke-test.sh production $TAG'
                    } catch (err) {
                        sh './scripts/rollback.sh production'
                        error "Production smoke test failed. Rolled back."
                    }
                }
            }
        }
    }

    post {
        always {
            sh 'docker logout || true'
        }
        success {
            echo "Released ${env.TAG} to production"
        }
    }
}

pipeline {
    agent any

    parameters {
        choice(
            name: 'ACTION',
            choices: ['apply', 'destroy'],
            description: 'Choose whether to apply or destroy infrastructure'
        )
    }

    environment {
        DOCKER_IMAGE = "laly9999/multi-cloud-app:${BUILD_NUMBER}"

        AWS_REGION   = "us-east-1"
        EKS_CLUSTER  = "eks-demo"

        AZURE_RG     = "aks-rg"
        AZURE_AKS    = "aks-demo"

        GCP_PROJECT  = "x-object-472022-q2"
        GCP_ZONE     = "us-east4-a"
        GKE_CLUSTER  = "gke-demo"
    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch : 'main' , url: 'https://github.com/lily4499/multi-cloud-deploy.git'
            }
        }

        stage('Terraform Infra') {
            steps {
                withCredentials([
                    string(credentialsId: 'arm-subscription-id', variable: 'ARM_SUBSCRIPTION_ID'),
                    string(credentialsId: 'arm-client-id', variable: 'ARM_CLIENT_ID'),
                    string(credentialsId: 'arm-client-secret', variable: 'ARM_CLIENT_SECRET'),
                    string(credentialsId: 'arm-tenant-id', variable: 'ARM_TENANT_ID'),
                    [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds'],
                    file(credentialsId: 'gcp-sa-key', variable: 'GOOGLE_APPLICATION_CREDENTIALS')
                ]) {
                    sh """
                    cd terraform
                    terraform init
                    if [ "$ACTION" = "apply" ]; then
                        terraform apply -auto-approve
                    else
                        terraform destroy -auto-approve
                    fi
                    """
                }
            }
        }

        stage('Build & Push Docker Image') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh """
                    echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                    cd app
                    docker build -t $DOCKER_IMAGE .
                    docker push $DOCKER_IMAGE
                    """
                }
            }
        }

        stage('Deploy to AWS EKS') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    sh """
                    aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER --alias eks-demo
                    helm upgrade --install myapp-eks ./helm-chart -f helm-chart/values-eks.yaml --set image.tag=${BUILD_NUMBER}
                    """
                }
            }
            post {
                success {
                    script {
                        def eks_url = sh(script: "kubectl get svc myapp-eks -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'", returnStdout: true).trim()
                        if (eks_url) {
                            echo "🌐 EKS App URL: http://${eks_url}"
                        } else {
                            echo "⚠️ EKS Service external hostname not ready yet. Run: kubectl get svc myapp-eks"
                        }
                    }
                }
            }
        }

        stage('Deploy to Azure AKS') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                withCredentials([
                    string(credentialsId: 'arm-client-id', variable: 'ARM_CLIENT_ID'),
                    string(credentialsId: 'arm-client-secret', variable: 'ARM_CLIENT_SECRET'),
                    string(credentialsId: 'arm-tenant-id', variable: 'ARM_TENANT_ID'),
                    string(credentialsId: 'arm-subscription-id', variable: 'ARM_SUBSCRIPTION_ID')
                ]) {
                    sh """
                    az login --service-principal \
                        -u $ARM_CLIENT_ID \
                        -p $ARM_CLIENT_SECRET \
                        --tenant $ARM_TENANT_ID
                    az account set --subscription $ARM_SUBSCRIPTION_ID
                    az aks get-credentials --resource-group $AZURE_RG --name $AZURE_AKS --overwrite-existing
                    helm upgrade --install myapp-aks ./helm-chart -f helm-chart/values-aks.yaml --set image.tag=${BUILD_NUMBER}
                    """
                }
            }
            post {
                success {
                    script {
                        def aks_ip = sh(script: "kubectl get svc myapp-aks -o jsonpath='{.status.loadBalancer.ingress[0].ip}'", returnStdout: true).trim()
                        if (aks_ip) {
                            echo "🌐 AKS App URL: http://${aks_ip}"
                        } else {
                            echo "⚠️ AKS Service external IP not ready yet. Run: kubectl get svc myapp-aks"
                        }
                    }
                }
            }
        }

        stage('Deploy to Google GKE') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                withCredentials([file(credentialsId: 'gcp-sa-key', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
                    sh """
                    export USE_GKE_GCLOUD_AUTH_PLUGIN=True
                    gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS
                    gcloud config set project $GCP_PROJECT
                    gcloud container clusters get-credentials $GKE_CLUSTER --zone $GCP_ZONE --project $GCP_PROJECT
                    helm upgrade --install myapp-gke ./helm-chart -f helm-chart/values-gke.yaml --set image.tag=${BUILD_NUMBER}
                    """
                }
            }
            post {
                success {
                    script {
                        def gke_ip = sh(script: "kubectl get svc myapp-gke -o jsonpath='{.status.loadBalancer.ingress[0].ip}'", returnStdout: true).trim()
                        if (gke_ip) {
                            echo "🌐 GKE App URL: http://${gke_ip}"
                        } else {
                            echo "⚠️ GKE Service external IP not ready yet. Run: kubectl get svc myapp-gke"
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            echo "Cleanup: remove local Docker images"
            sh "docker rmi $DOCKER_IMAGE || true"
        }
    }
}



















// pipeline {
//     agent any

//     environment {
//         DOCKER_IMAGE = "laly9999/multi-cloud-app:${BUILD_NUMBER}"
        
//         AWS_REGION   = "us-east-1"
//         EKS_CLUSTER  = "eks-demo"

//         AZURE_RG     = "aks-rg"
//         AZURE_AKS    = "aks-demo"

//         GCP_PROJECT  = "x-object-472022-q2"
//         GCP_ZONE     = "us-east4-a"
//         GKE_CLUSTER  = "gke-demo"
//     }

//     stages {
//         stage('Checkout Code') {
//             steps {
//                 git branch: 'main', url: 'https://github.com/lily4499/multi-cloud-deploy.git'
//             }
//         }

//         stage('Terraform Apply Infra') {
//             steps {
//                 withCredentials([
//                     string(credentialsId: 'arm-subscription-id', variable: 'ARM_SUBSCRIPTION_ID'),
//                     string(credentialsId: 'arm-client-id', variable: 'ARM_CLIENT_ID'),
//                     string(credentialsId: 'arm-client-secret', variable: 'ARM_CLIENT_SECRET'),
//                     string(credentialsId: 'arm-tenant-id', variable: 'ARM_TENANT_ID'),
//                     [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds'],
//                     file(credentialsId: 'gcp-sa-key', variable: 'GOOGLE_APPLICATION_CREDENTIALS')
//                 ]) {
//                     sh """
//                     cd terraform
//                     terraform init
//                     terraform apply -auto-approve
//                     """
//                 }
//             }
//         }

//         stage('Build & Push Docker Image') {
//             steps {
//                 withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
//                     sh """
//                     echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
//                     cd app
//                     docker build -t $DOCKER_IMAGE .
//                     docker push $DOCKER_IMAGE
//                     """
//                 }
//             }
//         }

//         stage('Deploy to AWS EKS') {
//             steps {
//                 withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
//                     sh """
//                     aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER --alias eks-demo
//                     helm upgrade --install myapp-eks ./helm-chart -f helm-chart/values-eks.yaml --set image.tag=${BUILD_NUMBER}
//                     """
//                 }
//             }
//         }

//         stage('Deploy to Azure AKS') {
//             steps {
//                 withCredentials([
//                     string(credentialsId: 'arm-client-id', variable: 'ARM_CLIENT_ID'),
//                     string(credentialsId: 'arm-client-secret', variable: 'ARM_CLIENT_SECRET'),
//                     string(credentialsId: 'arm-tenant-id', variable: 'ARM_TENANT_ID'),
//                     string(credentialsId: 'arm-subscription-id', variable: 'ARM_SUBSCRIPTION_ID')
//                 ]) {
//                     sh """
//                     az login --service-principal \
//                         -u $ARM_CLIENT_ID \
//                         -p $ARM_CLIENT_SECRET \
//                         --tenant $ARM_TENANT_ID
//                     az account set --subscription $ARM_SUBSCRIPTION_ID
//                     az aks get-credentials --resource-group $AZURE_RG --name $AZURE_AKS --overwrite-existing
//                     helm upgrade --install myapp-aks ./helm-chart -f helm-chart/values-aks.yaml --set image.tag=${BUILD_NUMBER}
//                     """
//                 }
//             }
//         }

//         stage('Deploy to Google GKE') {
//             steps {
//                 withCredentials([file(credentialsId: 'gcp-sa-key', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
//                     sh """
//                     gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS
//                     gcloud config set project $GCP_PROJECT
//                     export USE_GKE_GCLOUD_AUTH_PLUGIN=True
//                     gcloud container clusters get-credentials $GKE_CLUSTER --zone $GCP_ZONE --project $GCP_PROJECT
//                     helm upgrade --install myapp-gke ./helm-chart -f helm-chart/values-gke.yaml --set image.tag=${BUILD_NUMBER}
//                     """
//                 }
//             }
//         }
//     }

//     post {
//         always {
//             echo "Cleanup: remove local Docker images"
//             sh "docker rmi $DOCKER_IMAGE || true"
//         }
//     }
// }

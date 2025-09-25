

* **Terraform Apply** → Create AKS, EKS, GKE clusters.
* **Build & Push App** → Docker image to DockerHub.
* **Helm Deploy** → Helm chart with cloud-specific values.
* **Validation** → `kubectl` & browser check.
* **CI/CD automation** → Use Jenkins & GitHub.
---

# 🗂 Project Layout

```
multi-cloud-deploy/
├─ terraform/
│  ├─ aks.tf
│  ├─ eks.tf
│  ├─ gke.tf
│  └─ providers.tf
├─ app/
│  ├─ Dockerfile
│  ├─ server.js
│  └─ package.json
└─ helm-chart/
   ├─ Chart.yaml
   ├─ values.yaml
   ├─ values-aks.yaml
   ├─ values-eks.yaml
   ├─ values-gke.yaml
   └─ templates/
      ├─ deployment.yaml
      └─ service.yaml
```

---

# ⚙️ Step 1: Terraform Apply (AKS, EKS, GKE)

### `terraform/providers.tf`

```hcl
terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~>3.0" }
    aws     = { source = "hashicorp/aws", version = "~>5.0" }
    google  = { source = "hashicorp/google", version = "~>5.0" }
  }
}

provider "azurerm" { features {} }
provider "aws"     { region = "us-east-1" }
provider "google"  { project = "my-gcp-project" region = "us-central1" }
```

### `terraform/aks.tf` (Azure AKS, simple demo)

```hcl
resource "azurerm_resource_group" "aks_rg" {
  name     = "aks-rg"
  location = "East US"
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-demo"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  dns_prefix          = "aksdemo"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_B2s"
  }

  identity { type = "SystemAssigned" }
}
```

### `terraform/eks.tf` (AWS EKS, simple demo)

```hcl
resource "aws_eks_cluster" "eks" {
  name     = "eks-demo"
  role_arn = "arn:aws:iam::<ACCOUNT_ID>:role/EKSClusterRole"

  vpc_config {
    subnet_ids = ["subnet-xxxx", "subnet-yyyy"]
  }
}
```

### `terraform/gke.tf` (GCP GKE, simple demo)

```hcl
resource "google_container_cluster" "gke" {
  name     = "gke-demo"
  location = "us-central1-a"
  initial_node_count = 1
}
```

---


---

# ⚙️ Step 2: Build & Push App (DockerHub)

### `app/Dockerfile`

```dockerfile
FROM node:18
WORKDIR /app
COPY package.json ./
RUN npm install
COPY . .
CMD ["node", "server.js"]
```

### `app/server.js`

```js
const express = require("express");
const app = express();
app.get("/", (req, res) => res.send("Hello Multi-Cloud!"));
app.listen(3000, () => console.log("App running on port 3000"));
```

### CLI

```bash
cd app
docker build -t laly9999/multi-cloud-app:1 .
docker push laly9999/multi-cloud-app:1
```

# Validate locally (optional)

```bash

docker run -p 3000:3000 laly9999/multi-cloud-app:1

```
Open http://localhost:3000
 → should show Hello Multi-Cloud!
---



# ⚙️ Step 3: Helm Deploy

### `helm-chart/Chart.yaml`

```yaml
apiVersion: v2
name: multi-cloud-app
version: 0.1.0
```

### `helm-chart/templates/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: multi-cloud-app
  template:
    metadata:
      labels:
        app: multi-cloud-app
    spec:
      containers:
        - name: app
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          ports:
            - containerPort: 3000
```

### `helm-chart/templates/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 3000
  selector:
    app: multi-cloud-app
```

### `values-eks.yaml`

```yaml
replicaCount: 2
image:
  repository: laly9999/multi-cloud-app
  tag: "1"
```

(same structure for `values-aks.yaml` and `values-gke.yaml`)

### CLI

```bash
cd helm-chart

``bash

Run:

export GOOGLE_APPLICATION_CREDENTIALS="/home/lilia/DevOps/testtest/terraform-sa.json"

export ARM_SUBSCRIPTION_ID=8a984e27-9b68-475f-a7f6-5a053aff04c7
export ARM_CLIENT_ID=83c7c765-edf1-4e8d-bea7-ca91a54ec0d0
export ARM_CLIENT_SECRET=
export ARM_TENANT_ID=7b1e979c-5f76-4b25-97a5-7a3073b921bb

cd terraform

terraform init
terraform plan
terraform apply --auto-approve



Connect with kubectl:

aws eks update-kubeconfig --region us-east-1 --name eks-demo --alias eks-demo
kubectl config use-context eks-demo
kubectl get nodes
helm install myapp-eks ./helm-chart -f values-eks.yaml
# Validation
kubectl get pods
kubectl get svc


gcloud container clusters get-credentials gke-demo --region us-east4-a --project x-object-472022-q2
kubectl config use-context gke-demo
kubectl get nodes
helm install myapp-gke ./helm-chart -f values-gke.yaml
# Validation
kubectl get pods
kubectl get svc


#az account set --subscription 8a984e27-9b68-475f-a7f6-5a053aff04c7
az aks get-credentials --resource-group aks-rg --name aks-demo --overwrite-existing
kubectl config use-context aks-demo
kubectl get nodes
helm install myapp-aks ./helm-chart -f values-aks.yaml
# Validation
kubectl get pods
kubectl get svc
```

---

A unified Bash script that:

Switches kubeconfig context per cloud.

Runs Helm deploy.

Waits until the EXTERNAL-IP is assigned.

Prints out the service URL for each cluster.

# deploy-multicloud.sh

```bash
#!/bin/bash
set -e

APP_NAME="multiapp"
CHART_PATH="multi-cloud-deploy/helm-chart"
IMAGE_TAG=${1:-1} # Pass build number or default to 1

# --- Deploy to AWS EKS ---
echo "🚀 Deploying to AWS EKS..."
aws eks update-kubeconfig --region us-east-1 --name eks-demo --alias eks-demo
helm upgrade --install ${APP_NAME}-eks $CHART_PATH -f $CHART_PATH/values-eks.yaml --set image.tag=$IMAGE_TAG

echo "⏳ Waiting for EKS service external IP..."
kubectl wait --for=condition=available --timeout=300s deployment/${APP_NAME}-eks
sleep 10
EKS_IP=$(kubectl get svc ${APP_NAME}-eks -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "✅ EKS App URL: http://$EKS_IP"


# --- Deploy to Azure AKS ---
echo "🚀 Deploying to Azure AKS..."
az aks get-credentials --resource-group aks-rg --name aks-demo --overwrite-existing
helm upgrade --install ${APP_NAME}-aks $CHART_PATH -f $CHART_PATH/values-aks.yaml --set image.tag=$IMAGE_TAG

echo "⏳ Waiting for AKS service external IP..."
kubectl wait --for=condition=available --timeout=300s deployment/${APP_NAME}-aks
sleep 10
AKS_IP=$(kubectl get svc ${APP_NAME}-aks -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "✅ AKS App URL: http://$AKS_IP"


# --- Deploy to Google GKE ---
echo "🚀 Deploying to Google GKE..."
gcloud container clusters get-credentials gke-demo --zone us-east4-a --project x-object-472022-q2
helm upgrade --install ${APP_NAME}-gke $CHART_PATH -f $CHART_PATH/values-gke.yaml --set image.tag=$IMAGE_TAG

echo "⏳ Waiting for GKE service external IP..."
kubectl wait --for=condition=available --timeout=300s deployment/${APP_NAME}-gke
sleep 10
GKE_IP=$(kubectl get svc ${APP_NAME}-gke -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "✅ GKE App URL: http://$GKE_IP"

echo ""
echo "🌍 Multi-Cloud Deployments Complete!"
echo "-----------------------------------"
echo "EKS: http://$EKS_IP"
echo "AKS: http://$AKS_IP"
echo "GKE: http://$GKE_IP"


```



# CLEANUP

```bash
helm uninstall multiapp-eks
helm uninstall multiapp-aks
helm uninstall multiapp-gke
kubectl delete all --all
```

---


✅ Done. You now have **Terraform infra + Dockerized app + Helm chart** deployed on AKS, EKS, GKE.


---------------

-------------------


Perfect 👍 let’s put it all together — a **secure, multi-cloud Jenkinsfile** that:

1. Checks out code.
2. Provisions infra with Terraform.
3. Builds & pushes Docker image.
4. Deploys to **EKS, AKS, and GKE** using Helm.
5. Injects credentials from Jenkins securely.

---
---

# 🗂 Complete Jenkinsfile

```groovy
pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "laly9999/multi-cloud-app:${BUILD_NUMBER}"

        # Cluster names
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
                git 'https://github.com/youruser/multi-cloud-deploy.git'
            }
        }

        stage('Terraform Apply Infra') {
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
                    terraform apply -auto-approve
                    """
                }
            }
        }

        stage('Build & Push Docker Image') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
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
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    sh """
                    aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER --alias eks-demo
                    helm upgrade --install myapp-eks ./helm-chart -f helm-chart/values-eks.yaml --set image.tag=${BUILD_NUMBER}
                    """
                }
            }
        }

        stage('Deploy to Azure AKS') {
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
        }

        stage('Deploy to Google GKE') {
            steps {
                withCredentials([file(credentialsId: 'gcp-sa-key', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
                    sh """
                    gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS
                    gcloud config set project $GCP_PROJECT
                    gcloud container clusters get-credentials $GKE_CLUSTER --zone $GCP_ZONE --project $GCP_PROJECT
                    helm upgrade --install myapp-gke ./helm-chart -f helm-chart/values-gke.yaml --set image.tag=${BUILD_NUMBER}
                    """
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
```

---

# 🔑 Credentials Needed in Jenkins

| ID                    | Type               | Purpose                 |
| --------------------- | ------------------ | ----------------------- |
| `aws-creds`           | AWS credentials    | Deploy to EKS           |
| `arm-client-id`       | Secret text        | Azure SP client ID      |
| `arm-client-secret`   | Secret text        | Azure SP secret         |
| `arm-tenant-id`       | Secret text        | Azure tenant ID         |
| `arm-subscription-id` | Secret text        | Azure subscription ID   |
| `gcp-sa-key`          | Secret file (JSON) | GCP service account key |
| `dockerhub-creds`     | Username/Password  | Push to DockerHub       |

---

⚡ This Jenkinsfile will:

* Spin up clusters (Terraform).
* Build & push app image to DockerHub.
* Deploy app with Helm to **EKS, AKS, GKE**.

---
TROUBLESHOOTING:

 the Jenkins pipeline service account does **not** have permission to create the ClusterRoleBinding itself.

That’s expected:

* **Creating RBAC bindings** (`clusterrolebindings.rbac.authorization.k8s.io`) is a **cluster-admin only** action.
* Since this service account only has limited GKE access, it cannot grant itself higher privileges.

---

## 🔑 What this means

We can’t make Jenkins auto-elevate itself. Someone with **cluster-admin privileges** (usually your GCP IAM user account) must **bootstrap the RBAC once**. After that, the pipeline will work normally.

---

## ✅ Fix Steps

### 1. Log in with your GCP user (not the service account Jenkins uses):

```bash
gcloud auth login
gcloud container clusters get-credentials gke-demo --zone us-east4-a --project x-object-472022-q2
```

### 2. Apply the RBAC binding once:

```bash
kubectl create clusterrolebinding terraform-admin-binding \
  --clusterrole=cluster-admin \
  --user=terraform-admin@x-object-472022-q2.iam.gserviceaccount.com
```

### 3. Verify:

```bash
kubectl get clusterrolebinding terraform-admin-binding
```

Now the service account has cluster-admin, and Jenkins pipelines can install Helm charts without hitting `secrets forbidden`.

---

## 🚀 Best practice

* Do **RBAC bootstrapping once manually** with your own account.
* Keep the Jenkinsfile only for deployments (don’t try to create clusterrolebindings there).
* If you want a repeatable setup, save the RBAC in YAML:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: terraform-admin-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: User
  name: terraform-admin@x-object-472022-q2.iam.gserviceaccount.com
  apiGroup: rbac.authorization.k8s.io
```

Then apply once:

```bash
kubectl apply -f rbac.yaml
```

---

⚠️ Important: This cannot be fully automated inside Jenkins, because Jenkins doesn’t yet have the privilege to grant itself new privileges.

---




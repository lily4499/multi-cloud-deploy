# --- EKS Cluster (uses your pre-created role) ---
resource "aws_eks_cluster" "eks" {
  name     = "eks-demo"
  role_arn = "arn:aws:iam::637423529262:role/eks-cluster-role" # <-- use your role

  vpc_config {
    subnet_ids = [
      "subnet-062bafb72ff1b9c71",
      "subnet-00f1308ab05d4d97a"
    ]
    endpoint_public_access = true
  }
}

# --- Node Group (uses your pre-created role) ---
resource "aws_eks_node_group" "eks_nodes" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "eks-demo-ng"
  node_role_arn   = "arn:aws:iam::637423529262:role/eks-node-group-role-a" # <-- use your role -Join the EKS cluster - Configure networking - Pull images from ECR
  subnet_ids      = [
    "subnet-062bafb72ff1b9c71",
    "subnet-00f1308ab05d4d97a"
  ]

  scaling_config {
    desired_size = 1   # minimal: 1 node
    max_size     = 1
    min_size     = 1
  }

  instance_types = ["t3.small"]   # small, cheap instance
  ami_type       = "AL2023_x86_64_STANDARD"   # Amazon Linux 2
}

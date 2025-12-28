module "network" {
  source              = "./modules/network"
  region              = var.region
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
}

module "eks" {
  source             = "./modules/eks"
  cluster_name       = var.cluster_name
  vpc_id             = module.network.vpc_id
  public_subnet_ids  = [module.network.public_subnet_id]
  node_instance_type = var.node_instance_type
}

module "rds" {
  source             = "./modules/rds"
  vpc_id             = module.network.vpc_id
  private_subnet_ids = [module.network.private_subnet_id]
  db_identifier      = var.db_identifier
  db_name            = var.db_name
  db_username        = var.db_username
  db_instance_class  = var.db_instance_class
  allowed_sg_id      = module.eks.node_security_group_id
}

# Kubernetes provider configured after EKS is created
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# Namespaces for staging and production (can also be created by CI)
resource "kubernetes_namespace" "staging" {
  metadata {
    name = "staging"
  }
}

resource "kubernetes_namespace" "production" {
  metadata {
    name = "production"
  }
}

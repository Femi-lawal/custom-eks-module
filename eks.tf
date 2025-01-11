module "eks" {
  source = "./modules/aws/eks/v1"

  region              = var.region
  cluster_name        = var.cluster_name
  private_subnets     = module.vpc.private_subnets
  public_subnets      = module.vpc.public_subnets
  vpc_id              = module.vpc.vpc_id
  eks_cluster_version = "1.31"

  managed_node_groups = {
    demo_group = {
      name           = "demo-node-group"
      desired_size   = 2
      min_size       = 1
      max_size       = 3
      instance_types = ["t3a.small"]
    }
  }

  additional_role_mappings = [
    {
      rolearn  = aws_iam_role.cluster_autoscaler_role.arn
      username = "system:serviceaccount:kube-system:cluster-autoscaler"
      groups   = ["system:masters"]
    }
  ]

  additional_launch_template_tags = {
      "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
      "k8s.io/cluster-autoscaler/enabled"             = "true"    
  }
}


############################################################################################################
### AUTOSCALING
############################################################################################################
data "aws_iam_policy_document" "cluster_autoscaler_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
    }

    principals {
      identifiers = ["${module.eks.oidc_provider_arn}"]
      type        = "Federated"
    }
  }
}

# IAM Role for Cluster Autoscaler
resource "aws_iam_role" "cluster_autoscaler_role" {
  name               = "${var.cluster_name}-cluster-autoscaler"
  assume_role_policy = data.aws_iam_policy_document.cluster_autoscaler_assume_role_policy.json
}

# Custom policy for Cluster Autoscaler
data "aws_iam_policy_document" "cluster_autoscaler_policy" {
  statement {
    effect = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:GetInstanceTypesFromInstanceRequirements",
      "eks:DescribeNodegroup"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "cluster_autoscaler_policy" {
  name   = "${var.cluster_name}-cluster-autoscaler-policy"
  role   = aws_iam_role.cluster_autoscaler_role.id
  policy = data.aws_iam_policy_document.cluster_autoscaler_policy.json
}

output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "The endpoint for the EKS API server."
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate authority data required to communicate with the cluster."
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "node_role_arn" {
  description = "The ARN of the IAM role used by the EKS worker nodes."
  value       = aws_iam_role.node_role.arn
}

output "worker_node_sg_id" {
  description = "The Security Group ID created by EKS for the worker nodes."
  # The EKS cluster resource itself exposes the SG ID used by the control plane,
  # which usually governs access to the worker nodes. We reference it here.
  value = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}
### Outputs
output "node_ami" { value = data.aws_ami.eks-node.id }

output "node_userdata" {
  value = <<USERDATA
#!/bin/bash
set -o xtrace
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.eks.endpoint}' --b64-cluster-ca '${aws_eks_cluster.eks.certificate_authority[0].data}' '${var.name}'
USERDATA
}

output "sg" { value = aws_security_group.eks.id }
output "id" { value = aws_eks_cluster.eks.id }

output "endpoint" { value = aws_eks_cluster.eks.endpoint }
output "ca_data"  { value = aws_eks_cluster.eks.certificate_authority[0].data }
output "version"  { value = aws_eks_cluster.eks.version }

# vim:filetype=terraform ts=2 sw=2 et:

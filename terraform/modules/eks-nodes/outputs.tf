### Outputs
output "node_sg" { value = aws_security_group.eks-node.id }

output "node_role_arn"  { value = aws_iam_role.eks-cluster-node.arn }
output "node_role_name" { value = aws_iam_role.eks-cluster-node.name }

output "node_template"      { value = module.tpl.id }
output "node_template_arn"  { value = module.tpl.arn }
output "node_scaling_group" { value = module.asg.id }

output "policy_resize"      { value = module.asg.policy_resize }

# vim:filetype=terraform ts=2 sw=2 et:

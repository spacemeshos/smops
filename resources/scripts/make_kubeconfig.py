#!/usr/bin/env python3
# -*- coding: UTF-8 -*-

import argparse
import botocore.session

### Defaults
eks_admin_role = "arn:aws:iam::534354616613:role/spacemesh-eks-admin"
aws_profile = ""
name_prefix = "spacemesh-testnet-"
config_filename = "config.spacemesh"

### Parse arguments
parser = argparse.ArgumentParser(description="Generate kubernetes client configuration file")
parser.add_argument("-c", "--config", "--kube-config", type=str, default=config_filename, dest="KUBECONFIG",
                    help="Write to the file specified")
parser.add_argument("-p", "--profile", "--aws-profile", type=str, default=aws_profile, dest="AWS_PROFILE",
                    help="Set AWS_PROFILE to this value while calling aws-iam-authenticator")
parser.add_argument("-r", "--role", "--iam-role", type=str, default=eks_admin_role, dest="IAM_ROLE",
                    help="Use IAM_ROLE in aws-iam-authenticator")

args = parser.parse_args()

if args.AWS_PROFILE:
    aws_profile = args.AWS_PROFILE
if args.KUBECONFIG:
    config_filename = args.KUBECONFIG
if args.IAM_ROLE:
    eks_admin_role = args.IAM_ROLE

cluster_info = {}

for region in [
        "us-east-1",
        "us-east-2",
        "us-west-2",
        "ap-northeast-2",
        "eu-north-1",
        ]:
    eks = botocore.session.get_session().create_client("eks", region_name=region)
    print(f"Listing clusters in {region}")

    for cluster in eks.list_clusters()["clusters"]:
        if not cluster.startswith(name_prefix):
            print(f"Skipping {cluster} as it does not begin with {name_prefix}")
            continue

        print(f"Describing {cluster}")
        info = eks.describe_cluster(name=cluster)["cluster"]

        cluster_name = cluster[len(name_prefix):]
        print(f"Recording {cluster} as {cluster_name}")
        cluster_info[cluster_name] = {
            "id": cluster,
            "cadata": info["certificateAuthority"]["data"],
            "endpoint": info["endpoint"],
            }

print(f"Recording kubeconfig to {config_filename}")

with open(config_filename, "w") as kubeconfig:
    # Header
    kubeconfig.write("""\
apiVersion: v1
kind: Config
preferences: {}
""")

    # clusters
    kubeconfig.write("clusters:\n")
    for name, info in cluster_info.items():
        kubeconfig.write(f"""\
- name: {name}
  cluster:
    certificate-authority-data: {info["cadata"]}
    server: {info["endpoint"]}
""")

    # contexts
    kubeconfig.write("contexts:\n")
    for name in cluster_info.keys():
        kubeconfig.write(f"""\
- name: {name}
  context:
    cluster: {name}
    user: aws-{name}
""")

    # users
    kubeconfig.write("users:\n")
    for name, info in cluster_info.items():
        kubeconfig.write(f"""\
- name: aws-{name}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
      - token
      - -i
      - {info["id"]}
      - -r
      - {eks_admin_role}
""")
        # Add AWS_PROFILE is requested
        if aws_profile:
            kubeconfig.write(f"""\
      env:
        - name: AWS_PROFILE
          value: spacemesh
""")

print("Done!")

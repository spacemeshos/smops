=============================
GENERAL EKS CLUSTER BOOTSTRAP
=============================

This directory contains files related to general EKS Cluster bootstrap procedure. Script
``update-cluster-config.sh`` is used to apply configuration. Script ``update-spacemesh-config.sh``
updates just cluster-specific ConfigMaps - ``spacemesh-miner`` for Miner clusters and
``spacemesh-initfactory`` for InitFactory ones.



Components
==========

The following items are created in the cluster.

aws-auth ConfigMap
------------------

This ConfigMap in ``kube-system`` namespace is used by EKS to allow nodes to join the cluster. It
maps EC2 Instance's IAM Roles to the cluster nodes, granting them permissions to join. See
`Amazon EKS Documentation`_ for details.

Manifest for this ConfigMap is generated from a template - ``_aws-auth-configmap.tpl.sh`` defines
``get_aws_auth_configmap_manifest`` function which accepts two parameters - cluster type and AWS
Region name - and prints the manifest to standard output, to be consumed by ``kubectl`` through
``-f -`` parameter.


gp2-delayed StorageClass
------------------------

To ensure that a Miner or InitFactory worker gets its persistent storage volume in the same AWS
availability zone where the node it's scheduled resides at, a ``gp2-delayed`` StorageClass is
defined. It is based on standard ``gp2`` class but has ``WaitForFirstConsumer`` binding mode, and
volume expansion enabled.

Manifest is stored in ``gp2-delayed-storageclass.yml`` file.


metrics-server
--------------

Standard Kubernetes ``metrics-server`` is deployed from the manifest files under
``./metrics-server/`` subdirectory.

The manifests are identical to ones available in `metrics-server v0.3.4`_ distribution. They are
stored in this repository for simplicity and ease of applying them to all the clusters.


Helm
----

The script also installs Helm's Tiller and ensures it is running - which may be required to
automate new cluster bootstrap procedure.

To enable Tiller's operation, a ServiceAccount with ``cluster-admin`` privileges is created from
the manifest in ``tiller.yml``.

Current installation uses `Helm version 2.13.1`_.



Cluster-specific ConfigMap
==========================

Similar (but not identical) ConfigMaps are used to keep configuration items relevant to
InitFactory and Miner workloads. Management cluster currently does not have an equivalent as no
similar workloads run there.

The manifests for this ConfigMaps are generated from template in ``_spacemesh-configmap.tpl.sh``
similar to ``aws-auth`` ConfigMap generation.

As a shortcut a separate script can be used to update cluster-specific ConfigMaps.



.. _Amazon EKS Documentation: https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html
.. _metrics-server v0.3.4: https://github.com/kubernetes-sigs/metrics-server/tree/v0.3.4/deploy/1.8%2B
.. _Helm version 2.13.1: https://github.com/helm/helm/releases/tag/v2.13.1

.. vim: filetype=rst spell tw=98 ts=2 sw=2:

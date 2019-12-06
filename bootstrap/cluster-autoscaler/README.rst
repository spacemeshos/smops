==================
CLUSTER AUTOSCALER
==================

To adjust Auto Scaling Group sizes to the load, spacemesh InitFactory/Miner EKS Clusters uses
cluster-autoscaler_.


Details
=======

The deployment is based on the `stock manifest files`_ that come with cluster-autoscaler, with a few
adjustments.

The manifests are split in common part (see ``cluster-autoscaler-common.yml``) which defines the
ServiceAccount used by cluster-autoscaler and a template for particular Deployment in
``_cluster-autoscaler-deploy.tpl.sh`` shell script. In the template derived from the default
Deployment provided by cluster-autoscaler, specifying ``--node-group-auto-discovery`` parameter to
look for the Auto Scaling Group associated with the cluster's node pool - ``miner`` for Miner and
``initfactory`` for InitFactory clusters, respectively.

Management cluster doesn't have any dynamic node pools so it doesn't have cluster-autoscaler
installed.


Install/Update
==============

The ``update-cluster-autoscaler.sh`` script facilitates installation and update of
cluster-autoscaler in all/particular clusters. There are three modes of operations:

1. Update all the clusters: invoke the script with no parameters::

   ./update-cluster-autoscaler.sh

2. Update all the miner/initfactory clusters in all the regions: invoke with a single parameter,
   "miner" or "initfactory"::

   ./update-cluster-autoscaler.sh miner

3. Update miner/initfactory clusters in the specified regions: invoke with two or more parameters,
   cluster type ("miner"/"initfactory") and list of regions to process::

   ./update-cluster-autoscaler.sh miner us-east-1
   ./update-cluster-autoscaler.sh initfactory us-east-1 us-east-2


Internals
=========

``_cluster-autoscaler-deploy.tpl.sh`` defines a function which takes a single parameter - cluster
name. The function prints the YAML manifest to the standard output, for ``kubectl`` to grab it as
``-f -`` parameter.

``update-cluster-autoscaler.sh``, based on the parameters, invokes ``kubectl`` to apply the
configuration in each relevant context.


.. _cluster-autoscaler: https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler
.. _stock manifest files: https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml

.. vim: filetype=rst tw=98 ts=2 sw=2 spell:

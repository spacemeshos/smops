===================================
EFK STACK CONFIGURATION FOR LOGGING
===================================

spacemesh TestNet centralized logging is implemented on top EFK stack: Elasticsearch is used for
log storage, Fluent Bit is used to retrieve the logs from running pods, and Kibana is used to view
the logs.

As the network generates a lot of messages, with regular load spikes to 500,000 messages per
minute, Elasticsearch performance is crucial. To ensure reliable log delivery, a special instance
of Fluent Bit is running in forwarding mode, serving as a buffer between Elasticsearch and
individual log-shipping Fluent Bit instances.


Details
=======

Elasticsearch cluster is deployed to MGMT EKS Cluster and runs on 4 dedicated R-class instances.
There are two master and two data nodes configured, with 500GiB storage each to accommodate the
log messages.

To increase indexing speed some settings are tweaked (see ``./efk/es_settings.sh`` for details).

Though deployed by using the official Elastic Helm charts, some things are changed by hand to
improve the performance and manageability.

Elasticsearch nodes are run behind an Application Load Balancer (not managed by Kubernetes).

Kibana is installed using the official Elastic Helm chart too, and runs a single Pod the same
nodes as Elasticsearch. Kibana is exposed a NodePort service behind the same load balancer as
Elasticsearch for simplicity.

The load balancer is accessible only from the internal network so VPN connection is required to
use it.

For buffering Fluent Bit deployment details, see ``fluent-bit-forwarder`` subdirectory. For
per-worker-node Fluent Bit configuration, see ``fluent-bit`` subdirectory.

Master nodes of all clusters and ``logging`` pool nodes of management cluster run Fluent Bit which
ships the logs to Amazon CloudWatch Logs. See ``fluent-bit-master`` subdirectory for details.


Initial install
---------------

Official Elastic chart repo is added::

    helm repo add elastic https://helm.elastic.co

Then, the master and data nodes are deployed::

    helm install --namespace logging --version 7.3.0 --name logs-master elastic/elasticsearch -f values-mgmt-es.yml
    helm install --namespace logging --version 7.3.0 --name logs-data elastic/elasticsearch -f values-mgmt-es-data.yml

Kibana is deployed as follows::

    helm install --namespace logging --version 7.3.0 --name kibana elastic/kibana -f values-mgmt-kibana.yml

Manual changes
--------------

1. Helm-managed ``NodePort`` services for ``logs-master`` and ``logs-data`` are removed

2. The StatefulSets ``logs-master`` and ``logs-data`` are edited to expose container's port 9200
   as host port 31200 (see ``spec.template.spec.containers[0].ports``)

As the pods run on individual hosts (EC2 instances), exposing them through Kubernetes services
adds a layer of ``kube-proxy``. So, the actual nodes are masked from the ALB monitoring, and
Kubernetes also does some load balancing of its own, making the whole system hard to monitor and
troubleshoot.


Updating configuration
======================

Helm deployments can be modified as follows::

    helm upgrade logs-master elastic/elasticsearch --version 7.3.0 -f ./efk/values-mgmt-es.yml
    helm upgrade logs-data elastic/elasticsearch --version 7.3.0 -f ./efk/values-mgmt-es-data.yml

However it may fail because Elasticsearch startup is quite long, and pods may fail readiness
probes and get restarted. Also master election process is unreliable and often needs attention. So
caution is advised.

Also updating settings via Helm may revert changes done manually - this would mean either upgrade
failure or Elasticsearch downtime.

Kibana does not require any special treatment and can be upgraded as follows::

    helm upgrade kibana elastic/kibana --version 7.3.0 -f ./efk/values-mgmt-kibana.yml


Elasticsearch settings
======================

1. A custom ingestion pipeline is created to accompany each record with the time it was ingested
   by Elasticsearch, to troubleshoot any delay or data loss.

2. A custom template for ``kubernetes_cluster-*`` indices is created, specifying that log records
   should not have any replicas (to save space and increase performance), and increasing the
   refresh interval to reduce the load.



.. vim: filetype=rst tw=98 ts=2 sw=2:

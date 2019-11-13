====================
FLUENT BIT FORWARDER
====================

To improve log gathering performance, Fluent Bit is deployed into MGMT EKS Cluster in a forwarder
mode. Individual Fluent Bit instances ship the logs to this forwarder first, and then the
forwarder passes them to Elasticsearch. The log messages are buffered and fed in larger bulks
which is intended to increase ingestion time and reduce back pressure.


General
=======

The Fluent Bit Forwarder is deployed via a custom manifest to the ``logging`` node pool. In front
of nodes an internal Network Load Balancer is placed.

There is a deployment and a service called ``fluent-bit-buffer``, and a ``fluent-bit-buffer``
ConfigMap which contains:

1. ``logs_es_host`` value pointing to Elasticsearch load balancer

2. ``fluent-bit.conf`` value which is mounted as ``/fluent-bit/etc/fluent-bit.conf`` configuration
   file inside the container


Modifying configuration
=======================

As usual use ``kubectl`` to apply the changes to the manifests as follows::

    kubectl --context=mgmt-us-east-1 apply -f *.yml

However changes to ConfigMap do not lead to automatic restart so you should manually delete the
running pods with ``kubectl delete pod ...`` command.


.. vim: filetype=rst tw=98 ts=2 sw=2:

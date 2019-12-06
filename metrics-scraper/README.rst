=========================
SPACEMESH METRICS SCRAPER
=========================

This directory contains a custom metrics scraper script which runs in the TestNet clusters and
publishes a few custom Kubernetes and AWS EC2 metrics to Amazon CloudWatch.


Overview
========

The scraper script runs on EKS master nodes in all the clusters, using a special view-only
Kubernetes service account to describe nodes/pods/jobs/deployments status. Also it queries AWS API
to see the number of EBS volumes in the region and their state.

The metrics are pushed to CloudWatch in the corresponding region, to be available for further
analysis.

The script is written in Python and uses botocore_ library to talk to AWS and official `Kubernetes
Python binding`_ to get Kubernetes cluster statistics.

The container image is based on `Alpine Linux`_ (see ``Dockerfile`` for details).


CloudWatch
==========

There is a ``spacemesh`` dashboard in ``us-east-1`` region, which shows the graphs of the most
relevant spacemesh metrics: number of running nodes in InitFactory/Miner clusters, volumes used,
Miner and InitFactory worker pods, etc.

There are also a few CloudWatch alarms configured, to detect general TestNet health issues (if a
metrics scraper does not post any metrics for some time, or there are dangling volumes in the
region).



.. _botocore: https://botocore.readthedocs.io/
.. _Kubernetes Python binding: https://github.com/kubernetes-client/python
.. _Alpine Linux: https://alpinelinux.org/


.. vim: filetype=rst spell tw=98 ts=2 sw=2:

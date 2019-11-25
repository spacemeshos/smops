=============
SPACEMESH OPS
=============

This repository contains code related to spacemesh operations at Amazon Web Services platform.


Directories
===========

The directory layout is as follows.

``vars``, ``src``, ``resources``
  These subdirectories contain Jenkins pipeline code and resources

``bootstrap``
  This subdirectory contains scripts, Kubernetes manifests and Helm values files for applications
  deployed at the clusters

``metrics``
  This subdirectory contains code related to custom metrics scraper script

``initfactory``
  This subdirectory contains code related to InitFactory, which wraps spacemesh POST application to
  be used to generate initialization data files for miners

``miner``
  This subdirectory contains code related to ``miner-init`` - an application which downloads
  initialization data files from Amazon S3 to be used by a miner


Files
=====

``Jenkinsfile``
  Pipeline for Jenkins seed job


Details
=======

More details can be found in individual README files in corresponding subdirectories.



.. vim: filetype=rst tw=98 ts=2 sw=2 spell:

=============================================
InitFactory Wrapper for spacemesh POST server
=============================================

This is a wrapper around spacemesh initialization application, intended for
one-shot data generation - used as, for example, a Kubernetes Job workload.

Dockerfile builds an InitFactory variant of general POST server container: a
Python wrapper is deployed around the application.


General operation
=================

The wrapper does the following:

1. Calls ``spacemesh-init`` application with parameters built from the
   environment variables.
2. If the run was successful - the data is uploaded to S3 Bucket and some
   metadata is recorded into DynamoDB table.


Environment variables
=====================

SPACEMESH_ID
  *Required* The Miner ID for which to generate data

LOGLEVEL
  Sets log level, as specified by Python logging module (DEBUG/INFO are the
  most common values, INFO is the default)

SPACEMESH_FILESIZE, SPACEMESH_SPACE
  Values for ``-filesize`` and ``-space`` options.

SPACEMESH_DATADIR
  Base data directory (useful if, e.g., adding persistent volumes to the
  container).

SPACEMESH_S3_BUCKET, SPACEMESH_S3_PREFIX
  S3 Bucket and prefix under which to upload the init data.

SPACEMESH_DYNAMODB
  DynamoDB table to record the metadata to.

.. vim: set ts=2 sw=2 et tw=78 spell:

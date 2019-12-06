======================
FLUENT BIT LOG SHIPPER
======================

Fluent Bit is used to forward the logs from all the pods to a buffering Fluent Bit instance in the
management cluster.

Depending on cluster type, the logs are selected by the pod name using log path - FIXME: Change to
default.


Installing Fluent Bit
=====================

A wrapper script, ``install-fluent-bit.sh``, can be used to install Fluent Bit into a newly-added
cluster. The syntax is::

    ./install-fluent-bit.sh <cluster-type> <region> ...

If more than one region is given - Fluent Bit is installed in all of the instances of
``<cluster-type>`` in them.


Upgrading Fluent Bit
====================

A script ``upgrade-fluent-bit.sh`` can be used to upgrade Fluent Bit in all the clusters (default
if no parameters given) or only in a few of them::

    ./upgrade-fluent-big.sh <cluster-type> <region> ...


Details
=======

Fluent Bit is installed using standard Helm chart, ``stable/fluent-bit``.

The wrapper scripts source ``../../_config.inc.sh`` and ``./_chart.inc.sh`` configuration
snippets, containing TestNet-wide and application-specific configuration parameters.

A field that specifies the cluster from which the log message originates is added by
``record_modifier`` filter. As standard Helm chart does not support custom filters of that kind -
it is added as a ``rawConfig`` snippet. So, to upgrade Fluent Bit it may be necessary to review
``rawConfig`` part.

As each cluster has its own value for this additional field, plus each cluster type has different
path to logs and set of extra tolerations, instead of a static ``values.yaml`` a special function,
``get_values()``, is used. It is defined in ``_chart.inc.sh`` configuration file and dumps the
values to standard output. This function output is in turn piped to Helm.



.. vim: filetype=rst tw=98 ts=2 sw=2 spell:

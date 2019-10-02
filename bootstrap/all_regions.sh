#!/bin/bash

CMD=$1
shift

if [ -z "$CMD" ] ; then
    echo "Usage: $0 <script> [params]"
    exit 1
fi

. $(dirname $0)/_config.inc.sh || exit 2

for REGION in $REGIONS ; do
    echo "Calling $CMD $REGION" "$@"
    $CMD $REGION "$@"
done

# vim:set ts=4 sw=4 ai et:

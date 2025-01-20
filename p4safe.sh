#!/bin/bash


p4 where &>/dev/null
if [ $? -ne 0 ]; then
    echo "Invalid workdir, not a p4 workspace."
    exit 1
fi

if [ $# -gt 0 ]; then
    p4 $@
fi


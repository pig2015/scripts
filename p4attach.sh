#!/bin/bash

FWD="$(dirname -- "${BASH_SOURCE[0]}")"

$FWD/p4safe.sh  &>/dev/null
if [ $? -eq 0 ]; then
    echo "Current dir is already a p4 ws hence cannot attach, use 'p4 where' to check"
    exit 1
fi

CLIENT=$(basename $PWD)

p4 clients --me | grep $CLIENT  &>/dev/null
if [ $? -ne 0 ]; then
    echo "Invalid workdir, no matching p4 client: $CLIENT"
fi

if [ ! -f .p4config ]; then
    touch .p4config
fi

CLIENT_STR=$(grep "P4CLIENT=" .p4config)
if [ $? -eq 0 ]; then
    if [ "$CLIENT_STR" != "P4CLIENT=$CLIENT" ];then
        echo ".p4config contains mismatched P4CLIENT"
        echo "manually set P4CLIENT=$CLIENT to override"
    fi
else
    echo "" >> .p4config
    echo "P4CLIENT=$CLIENT" >> .p4config
    echo "p4 workspace attached, see ./.p4config"
fi


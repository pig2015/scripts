#!/bin/bash

if [[ $# == 0 ]]; then
    pwd
else
    for arg in "$@"
    do
        readlink -f $arg
    done
fi


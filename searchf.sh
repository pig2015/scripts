#!/bin/bash

if [[ $# == 1 ]]; then
    find . -name $1
elif [[ $# == 2 ]];then
    find $2 -name $1
else
    echo "Error. Usage: <cmd> <filename_pattern> [<folder>]"
fi


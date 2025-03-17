#!/bin/bash

if [[ $# == 1 ]]; then
    grep --color=always -rin $1 .
elif [[ $# == 2 ]];then
    grep --color=always -rin $1 $2
else
    echo "Error. Usage: <cmd> <grep_pattern> [<folder>]"
fi

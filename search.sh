#!/bin/bash

if [[ $# == 1 ]]; then
    grep --color=always -rin "$1" .
elif [[ $# == 2 ]];then
    if [ ! -e "$2" ]; then
        echo "Error. second arg is not a valid path: $2"; exit 1
    fi
    grep --color=always -rin "$1" $2
else
    echo "Error. Usage: <cmd> '<grep_regex_pattern>' [<folder>]"; exit 1
fi

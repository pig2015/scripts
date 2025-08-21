#!/bin/bash

if [[ $# == 1 ]]; then
    find . -name "$1" ! -type d
elif [[ $# == 2 ]];then
    find "$2" -name "$1" ! -type d
else
    echo "Error. Usage: <cmd> '<filename_glob_pattern>' [<folder>]"
fi


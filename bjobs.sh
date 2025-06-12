#!/bin/bash

while true; do
    echo "----"
    bjobs
    read -t 5 -n 1 input
    [[ $input == "Q" || $input == "q" ]] && break
done

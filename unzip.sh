#!/usr/bin/bash

for f in "$@"
do
    if [[ ! -f $f ]]; then
        continue
    fi

    if [[ $f == *".tar" ]]; then
        tar xvf $f
    elif [[ $f == *".tar.gz" ]]; then
        tar zxvf $f
    elif [[ $f == *".tar.bz2" ]]; then
        tar jxvf $f
    elif [[ $f == *".tgz" ]]; then
        tar zxvf $f
    elif [[ $f == *".gz" ]]; then
        gunzip $f
    elif [[ $f == *".zip" ]]; then
        unzip $f
    elif [[ $f == *".rar" ]]; then
        rar e $f
    elif [[ $f == *".bz2" ]]; then
	bunzip $f
    elif [[ $f == *".txz" ]]; then
        tar xvf $f
    else
        echo "Error: unidentified compression type: $f"
    fi
done

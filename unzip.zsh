#!/usr/bin/zsh

for f in "$@"
do
    if [[ ! -f $f ]]; then
        continue
    fi

    if [[ $f == *".tar" ]]; then
        tar xvf $f
    elif [[ $f == *".tar.gz" ]]; then
        tar zxvf $f
    elif [[ $f == *".tgz" ]]; then
        tar zxvf $f
    elif [[ $f == *".gz" ]]; then
        gunzip $f
    elif [[ $f == *".zip" ]]; then
        unzip $f
    elif [[ $f == *".rar" ]]; then
        rar e $f
    else
        echo "Error: unidentified compression type: $f"
    fi
done

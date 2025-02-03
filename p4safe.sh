#!/bin/bash


has_p4client() {
    config_path=$1/.p4config
    if [ ! -f $config_path ]; then
        echo 0
        return
    fi
    match=$(grep "P4CLIENT=*"  $config_path)
    if [ "$match" == "" ]; then
        echo 0
        return
    fi
    echo 1
}


is_p4ws() {
    dir=$1
    for _ in {1..100};
    do
        if [[ "$dir" == "$HOME" ]] || \
           [[ "$dir" == "/home" ]] || \
           [[ "$dir" == "/" ]]; then
            echo 0
            return
        fi
        res=$(has_p4client $dir)
        if [ "$res" == "1" ]; then
            echo 1
            return
        fi
        if [ -L $dir ]; then
            echo 0
            return
        fi
        dir=$(dirname $dir)
    done
}


# p4 where 1> /dev/null 2> /dev/null  # not supported under nv bash env
res=$(is_p4ws $PWD)
if [ "$res" -eq "0" ]; then
    echo "Invalid workdir, not a p4 workspace."
    exit 1
fi

if [ $# -gt 0 ]; then
    p4 $@
fi


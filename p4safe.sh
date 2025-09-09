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


is_sys_fullpath() {
    if [[ "$1" == ~/* ]]; then
        echo 1
    elif [[ "$1" == //* ]]; then  # p4 depot
        echo 0
    elif [[ "$1" == /* ]]; then
        echo 1
    else
        echo 0
    fi
}


to_realpath() {
    echo "$(readlink -f $1)"
}


is_sys_dirpath() {
    if [ -d "$1" ]; then
        echo 1
    else
        echo 0
    fi
}


normalize_dirpath() {
    if [[ "$1" =~ [[:alnum:]]/$ ]]; then
        echo "${1%/}"
    else
        echo "$1"
    fi
}


# find real path, p4 sometimes confused by symlink
cd $(pwd -P)

# not supported under nv bash env
# p4 where 1> /dev/null 2> /dev/null

res=$(is_p4ws $PWD)
if [ "$res" -eq "0" ]; then
    echo "Invalid workdir, not a p4 workspace."
    exit 1
fi

# process each arg

new_args=()

for arg in "$@"
do
    processed_arg="$arg"
    if [ "$(is_sys_dirpath $arg)" -eq "1" ]; then
        processed_arg=$(normalize_dirpath $arg)
    fi
    if [ "$(is_sys_fullpath $arg)" -eq "1" ]; then
        processed_arg=$(to_realpath $arg)
    fi
    new_args+=("$processed_arg")
done

# forward

if [ ${#new_args[@]} -gt 0 ]; then
    if [ "${P4SAFE_DISABLE_CMD_REPLAY}" != "1" ]; then
        echo "CMD> p4 ${new_args[@]}"
    fi
    p4 ${new_args[@]}
fi


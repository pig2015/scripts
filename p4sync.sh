#!/bin/bash


FWD="$(dirname -- "${BASH_SOURCE[0]}")"

p4safe=$FWD/p4safe.sh
p4safe_quite=$FWD/p4safe_quite.sh


$p4safe sync
sync_status=$?

if [ $sync_status != 0 ];then
    sync_err=$($p4safe_quite sync 2>&1 1>/dev/null)
    clobber_files_msg=$(echo $sync_err | grep "Can't clobber writable file" | sed "s/Can't clobber writable file //g")
    if [ "$clobber_files_msg" != "" ];then
        rm $clobber_files_msg
    fi
    non_clobber_err=$(echo $sync_err | grep -v "Can't clobber writable file")
    if [ "$non_clobber_err" != "" ];then
        echo "Contains non-clobber error, unable to process automatically."
        exit $sync_status
    fi
    $p4safe_quite sync
fi


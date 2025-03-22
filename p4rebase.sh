#!/bin/bash

set -e

FWD="$(dirname -- "${BASH_SOURCE[0]}")"

p4safe=$FWD/p4safe.sh


# pull
echo "== PULLING =="
$p4safe sync

# rebase previously opened for edit but now identical files
echo "== FAST-FORWARDING (IDENTICAL EDITS) =="
$p4safe revert -a

# rebase previously opened for edit but now no-conflicts files
echo "== FAST-FORWARDING (NO CONFLICTS EDITS) =="
$p4safe resolve -am

# pull again to find previously added files
echo "== FAST-FORWARDING (ADDS OPS) =="
added_sync_msg=$($p4safe sync | grep "opened for add and can't be replaced" || true)

# rebase previously added files
added_files_msg=$(echo "$added_sync_msg" | cut -d'#' -f1)
added_where_msg=$(echo "$added_files_msg" | xargs -I {} $p4safe where {})
added_remote_files=($(echo "$added_where_msg" | cut -d' ' -f1))  # to array
added_local_files=($(echo "$added_where_msg" | cut -d' ' -f3))  # to array

for ((i=0; i<${#added_remote_files[@]}; i++)); do
    added_remote_file=${added_remote_files[$i]}
    added_local_file=${added_local_files[$i]}
    echo "Processing: $added_local_file."
    rebasing_file=${added_local_file}.rebasing
    mv $added_local_file $rebasing_file
    $p4safe revert $added_local_file
    $p4safe sync $added_remote_file#1
    diff -q $added_local_file $rebasing_file > /dev/null
    if [ $? -ne 0 ]; then
        echo "Change detected."
        $p4safe edit $added_local_file
        cp $rebasing_file $added_local_file
    fi
    rm -f $rebasing_file
done

echo "== FAST-FORWARDING (ADDS POST-PULL) =="
$p4safe sync

echo "== FAST-FORWARDING (NO CONFLICTS ADDS) =="
$p4safe resolve -am  # pull again to find previously added files

echo "== FAST-FORWARDING (DELETE OPS) =="
deleted_opened_msg=$($p4safe opened | grep " - delete" || true)

# rebase previously deleted files
deleted_remote_files=($(echo "$deleted_opened_msg" | cut -d'#' -f1))  # to array

for ((i=0; i<${#deleted_remote_files[@]}; i++)); do
    deleted_remote_file=${deleted_remote_files[$i]}
    echo "Processing: $deleted_remote_file"
    have_msg=$($p4safe have $deleted_remote_file || true)
    # if file is not on remote, it will be stderr: "file(s) not on client."
    # otherwise stdout
    if [[ "$have_msg" == "" ]]; then
        $p4safe revert $deleted_remote_file
    fi
done

echo "== REVIEW CONFLICTS =="
$p4safe resolve -n

#!/bin/bash


FWD="$(dirname -- "${BASH_SOURCE[0]}")"

p4safe=$FWD/p4safe.sh
p4safe_quite=$FWD/p4safe_quite.sh


$p4safe sync
sync_status=$?

if [ $sync_status != 0 ];then
    sync_err=$($p4safe_quite sync 2>&1 1>/dev/null)
    clobber_prefix="Can't clobber writable file "

    # keep newlines / spaces intact: process line by line
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        case "$line" in
            "$clobber_prefix"*)
                target="${line#"$clobber_prefix"}"
                if [ -d "$target" ] && [ ! -L "$target" ]; then
                    # local dir collides with a depot file: only remove if empty
                    if ! rmdir "$target"; then
                        echo "Directory not empty, remove manually: $target"
                        exit $sync_status
                    fi
                else
                    rm -f -- "$target"
                fi
                ;;
            *)
                echo "Contains non-clobber error, unable to process automatically."
                echo "$line"
                exit $sync_status
                ;;
        esac
    done <<< "$sync_err"

    $p4safe_quite sync
fi


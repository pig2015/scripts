#!/bin/bash

error_found=false
force_mode=false

link_item() {
    local path="$1"
    if [ -e "$path" ]; then
        if $force_mode; then
            ln -sf "$path"
        else
            ln -s "$path"
        fi
    elif $force_mode; then
        echo "Warning: '$path' does not exist. Creating link anyway..." >&2
        ln -sf "$path"
    else
        echo "Error: '$path' does not exist." >&2
        error_found=true
    fi
}

args=()
for arg in "$@"; do
    if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
        echo "Usage:"
        echo "  $0 [-f|--force] <source1> <source2> ..."
        echo "Options:"
        echo "  -f, --force      Create links even if source does not exist"
        exit 0
    elif [[ "$arg" == "-f" || "$arg" == "--force" ]]; then
        force_mode=true
    else
        args+=("$arg")
    fi
done

if [ "${#args[@]}" -eq 0 ]; then
    echo "Invalid arguments. Use -h or --help to view usage." >&2
    exit 1
fi

for src in "${args[@]}"; do
    if [[ "$src" == *"*"* ]]; then
        matches=$(ls -d $src 2>/dev/null)
        if [ -n "$matches" ]; then
            for item in $matches; do
                link_item "$item"
            done
        else
            echo "Error: pattern '$src' did not match any file or directory." >&2
            error_found=true
        fi
    else
        link_item "$src"
    fi
done

if $error_found; then
    exit 1
else
    exit 0
fi

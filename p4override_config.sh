#!/bin/bash

FWD="$(dirname -- "${BASH_SOURCE[0]}")"

# check template config existence

if [ -z "${P4CONFIG_TEMPLATE}" ]; then
  echo "env P4CONFIG_TEMPLATE must be set, adding to shrc is recommanded"
  exit 1
fi

if [ ! -f $P4CONFIG_TEMPLATE ]; then
  echo "$P4CONFIG_TEMPLATE not exist"
  exit 1
fi

# avoid wrong place to exec

p4safe=$FWD/p4safe.sh
$p4safe  &>/dev/null
if [ $? -ne 0 ]; then
    echo "current dir is not a valid p4 ws"
    exit 1
fi

# locate p4config

P4CONFIG_PATH=$($p4safe set P4CONFIG | awk -F"'" '{print $2}' | xargs)
if [ ! -f $P4CONFIG_PATH ]; then
    echo "unable to locate path of p4config"
    exit 1
fi

echo "p4config located: $P4CONFIG_PATH"

# replace var from tmpl

tar_params="P4EDITOR P4DIFF"

declare -A tar_dict
while IFS='=' read -r key val; do
    [[ -z "$key" || "$key" =~ ^# ]] && continue
    tar_dict[$key]=$val
done < "$P4CONFIG_TEMPLATE"

tmpfile=$(mktemp)
cp "$P4CONFIG_PATH" "$tmpfile"

for param in $tar_params; do
    if [[ -n "${tar_dict[$param]}" ]]; then
        if grep -q "^$param=" "$tmpfile"; then
            oldval=$(grep "^$param=" "$tmpfile" | cut -d= -f2-)
            if [[ "$oldval" != "${tar_dict[$param]}" ]]; then
                sed -i "s|^$param=.*|$param=${tar_dict[$param]}|" "$tmpfile"
                echo "$param changed: $oldval -> ${tar_dict[$param]}"
            fi
        else
            echo "$param=${tar_dict[$param]}" >> "$tmpfile"
            echo "$param added: ${tar_dict[$param]}"
        fi
    fi
done

# backup and overwrite if changed

if cmp -s "$tmpfile" "$P4CONFIG_PATH"; then
    echo "no changes needed, $tar_params all as desired. original p4config kept."
    rm "$tmpfile"
    exit 0
fi

backup="${P4CONFIG_PATH}.bak_$(date +%Y%m%d_%H%M%S)"
cp "$P4CONFIG_PATH" "$backup"
mv "$tmpfile" "$P4CONFIG_PATH"

# print

echo "== overrided p4config =="
cat $P4CONFIG_PATH

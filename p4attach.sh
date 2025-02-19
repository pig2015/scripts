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

# avoid wrong place to init

$FWD/p4safe.sh  &>/dev/null
if [ $? -eq 0 ]; then
    if [ ! -f .p4config ]; then
        echo "current dir is already a p4 ws whereas not in root, use 'p4 where' to check"
        exit 1
    fi
fi

# check client remote existence

ATTACH_CLIENT=$(basename $PWD)

p4 clients --me | grep $ATTACH_CLIENT  &>/dev/null
if [ $? -ne 0 ]; then
    echo "invalid workdir, no matching p4 client to attch: $ATTACH_CLIENT"
    exit 1
fi

# backup and init .p4config

if [ -f .p4config ]; then
    cp -f .p4config .p4config_old
else
    touch .p4config
fi

# copy from template or replace (update)

matches=($(grep -E "^[^\s]+=[^\s]+" $P4CONFIG_TEMPLATE))

for match in "${matches[@]}"
do
    var=$(echo "$match" | cut -d'=' -f1)
    pat="$var=.*"
    grep -q "$pat" .p4config
    if [ $? -eq 0 ]; then
        sed -i "s|${pat}|${match}|g" .p4config
    else
        echo "$match" >> .p4config
    fi
done

# handle P4CLIENT

CLIENT_STR=$(grep "P4CLIENT=" .p4config)
if [ $? -eq 0 ]; then
    if [ "$CLIENT_STR" != "P4CLIENT=$ATTACH_CLIENT" ];then
        echo ".p4config contains mismatched P4CLIENT"
        echo "senstive var, manually set P4CLIENT=$ATTACH_CLIENT to override"
        exit 1
    fi
else
    echo "P4CLIENT=$ATTACH_CLIENT" >> .p4config
fi

# print
echo "== workdir p4config of client '$ATTACH_CLIENT' =="
cat .p4config

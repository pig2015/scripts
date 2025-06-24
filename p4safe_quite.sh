#!/bin/bash


FWD="$(dirname -- "${BASH_SOURCE[0]}")"

p4safe=$FWD/p4safe.sh

# forward

export P4SAFE_DISABLE_CMD_REPLAY=1

$p4safe $@

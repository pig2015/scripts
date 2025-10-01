#!/bin/bash

VIM_BIN=vimdiff
exec $VIM_BIN -c 'set diffopt+=iwhite' -c 'set number' "$@"


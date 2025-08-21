#!/bin/bash

echo "> chmod u+w -R $@;  rm -rf $@"

chmod u+w -R $@
rm -rf $@


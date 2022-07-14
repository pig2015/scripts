#!/bin/sh

web=kats.labcollab.net
wget -p $web
rm -rf $web
echo "temp file removed"


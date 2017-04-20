#!/bin/sh

cd /opt/crafty

bin/migrate

bin/crafty "$@"

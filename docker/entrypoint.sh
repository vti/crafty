#!/bin/sh

#set -x

PID=0

sig_handler() {
    if [ $PID -ne 0 ]; then
        kill -HUP $PID
        wait "$PID"
        PID=0
    fi

    exit 143
}

trap 'kill ${!}; sig_handler' HUP
trap 'kill ${!}; sig_handler' INT

cd /opt/crafty

bin/migrate

bin/crafty "$@" &

PID="$!"

while true
do
    tail -f /dev/null & wait ${!}
done

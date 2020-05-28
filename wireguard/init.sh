#!/bin/bash

/bin/wg-quick up wg0

function watchWireguard () {
    sleep 1
    psCount=$(ps aux|grep "wireguard-go"|wc -l)
    if [ $psCount -lt 2 ] ; then
        echo "wireguard-go exited"
        exit 1;
    else
        watchWireguard
    fi
}

watchWireguard

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
        exit 0
}

sleep infinity
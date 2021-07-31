#!/usr/bin/env bash

loop() {
    while true
    do
        read -e -r cmd
        eval $cmd
        if [[ $? -ne 0 ]]; then
            printf 'Errors have occurred\n'
        fi
        printf '\n\x03'
    done
}

sigint() {
    printf '\x03'  # Send ETX (end of text)
    loop
}

trap 'loop' SIGINT

loop

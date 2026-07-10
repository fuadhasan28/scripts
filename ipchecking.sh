#!/bin/bash

get_ip() {
    ipconfig | grep -E "IPv4 Address|IPv4-adresse" | awk -F: '{print $2}' | tr -d ' '
}

current_ip=$(get_ip)
echo "Initial IP: $current_ip"

while true; do
    new_ip=$(get_ip)
    if [ "$new_ip" != "$current_ip" ]; then
        echo "IP changed: $new_ip"
        current_ip=$new_ip
    fi
    sleep 5
done
#!/bin/bash

echo "Trying to connect to bitcartcc..."
while true; do
    if [ "$(curl -sL -w "%{http_code}\\n" "http://localhost/" -o /dev/null)" == "200" ]; then
        echo "Successfully contacted BitcartCC"
        break
    fi
    sleep 1
done

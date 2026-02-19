#!/bin/bash

echo "Trying to connect to bitcart..."
while true; do
    if [ "$(curl -sL -w "%{http_code}\\n" "http://localhost/api" -o /dev/null)" == "200" ]; then
        echo "Successfully contacted Bitcart"
        break
    fi
    sleep 1
done

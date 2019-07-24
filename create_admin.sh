#!/usr/bin/env bash

docker exec -it bitcart-docker_daemon_1 sh -c "python manage.py createsuperuser"

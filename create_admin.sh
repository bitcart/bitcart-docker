#!/usr/bin/env sh

docker exec -it bitcart-docker_daemon_1 sh -c "python manage.py createsuperuser"

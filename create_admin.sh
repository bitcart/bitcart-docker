#!/usr/bin/env sh

docker exec -it compose_backend_1 sh -c "python manage.py createsuperuser"

#!/usr/bin/env sh
set -ex
python3 manage.py makemigrations
python3 manage.py makemigrations gui
python3 manage.py migrate
python3 manage.py collectstatic
python3 manage.py runserver 0.0.0.0:8000

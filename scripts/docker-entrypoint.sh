#!/usr/bin/env bash
set -ex
python3 manage.py migrate --no-input
python3 manage.py collectstatic --no-input
gunicorn -c gunicorn.conf.py mainsite.wsgi:application

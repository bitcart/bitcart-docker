#!/usr/bin/env sh
set -ex
alembic upgrade head
gunicorn -c gunicorn.conf.py main:app

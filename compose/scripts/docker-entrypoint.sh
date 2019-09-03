#!/usr/bin/env sh
set -ex
gunicorn -c gunicorn.conf.py main:app

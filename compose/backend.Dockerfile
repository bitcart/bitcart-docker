FROM python:3.6-alpine

COPY bitcart /app
COPY scripts/docker-entrypoint.sh /usr/local/bin/
WORKDIR /app
RUN adduser -D electrum && \
    apk add --virtual build-deps --no-cache build-base libffi-dev && \
    apk add postgresql-dev && \
    pip install -r requirements.txt && \
    pip install -r requirements/production.txt && \
    rm -rf /root/.cache/pip && \
    apk del build-deps
USER electrum
CMD ["sh"]
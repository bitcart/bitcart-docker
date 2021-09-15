FROM python:3.7-slim-buster

ENV IN_DOCKER=1
LABEL org.bitcartcc.image=backend

COPY bitcart /app
COPY scripts/docker-entrypoint.sh /usr/local/bin/
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends iproute2 openssh-client python3-dev libffi-dev && \
    groupadd --gid 1000 electrum && \
    useradd --uid 1000 --gid electrum --shell /bin/bash --create-home electrum && \
    pip install -r requirements/deterministic/web.txt && \
    pip install -r requirements/deterministic/production.txt && \
    apt-get purge python3-dev libffi-dev && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /root/.cache/pip
USER electrum
CMD ["sh"]

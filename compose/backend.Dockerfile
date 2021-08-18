FROM python:3.7-slim-buster

ENV IN_DOCKER=1
LABEL org.bitcartcc.image=backend

COPY bitcart /app
COPY scripts/docker-entrypoint.sh /usr/local/bin/
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends iproute2 openssh-client && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd --gid 1000 electrum && \
    useradd --uid 1000 --gid electrum --shell /bin/bash --create-home electrum && \
    pip install -r requirements/deterministic/web.txt && \
    pip install -r requirements/deterministic/production.txt && \
    rm -rf /root/.cache/pip
USER electrum
CMD ["sh"]

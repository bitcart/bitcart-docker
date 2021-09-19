FROM golang:1.16-alpine AS go-builder

COPY bitcart/cli /app

RUN cd /app && \
    apk add --no-cache make && \
    CGO_ENABLED=0 make build ARGS="-ldflags '-X main.Version=docker -X main.envFile=/app/conf/.env'" && \
    chmod +x bitcart-cli


FROM python:3.7-slim-buster

ENV IN_DOCKER=1
LABEL org.bitcartcc.image=backend

COPY bitcart /app
COPY scripts/docker-entrypoint.sh /usr/local/bin/
COPY --from=go-builder /app/bitcart-cli /usr/local/bin/
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends iproute2 openssh-client build-essential python3-dev libffi-dev && \
    groupadd --gid 1000 electrum && \
    useradd --uid 1000 --gid electrum --shell /bin/bash --create-home electrum && \
    pip install -r requirements/deterministic/web.txt && \
    pip install -r requirements/deterministic/production.txt && \
    apt-get purge -y build-essential python3-dev libffi-dev && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /root/.cache/pip
USER electrum
CMD ["sh"]

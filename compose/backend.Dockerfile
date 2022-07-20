FROM golang:1.16-alpine AS go-builder

COPY bitcart/cli /app

RUN cd /app && \
    apk add --no-cache make && \
    CGO_ENABLED=0 make build ARGS="-ldflags '-X main.Version=docker -X main.envFile=/app/conf/.env'" && \
    chmod +x bitcart-cli


FROM python:3.9-slim-buster

ARG TARGETPLATFORM
ENV IN_DOCKER=1
ENV GOSU_VERSION 1.14
LABEL org.bitcartcc.image=backend

COPY bitcart /app
COPY scripts/docker-entrypoint.sh /usr/local/bin/
COPY scripts/setup-pypi-mirror.sh /usr/local/bin/
COPY --from=go-builder /app/bitcart-cli /usr/local/bin/
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends iproute2 openssh-client build-essential python3-dev libffi-dev ca-certificates wget && \
    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" && \
    wget -qO /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" && \
    chmod +x /usr/local/bin/gosu && \
    groupadd --gid 1000 electrum && \
    useradd --uid 1000 --gid electrum --shell /bin/bash --create-home electrum && \
    mkdir -p /datadir /backups && \
    chown electrum /datadir /backups && \
    setup-pypi-mirror.sh && \
    pip install -r requirements/deterministic/web.txt && \
    pip install -r requirements/deterministic/production.txt && \
    apt-get purge -y build-essential python3-dev libffi-dev wget && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /root/.cache/pip
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["sh"]

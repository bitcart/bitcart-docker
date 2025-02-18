FROM golang:1.23-alpine AS go-builder

RUN CGO_ENABLED=0 go install -ldflags '-X main.Version=docker -X main.envFile=/app/conf/.env' github.com/bitcart/bitcart-cli@master

FROM python:3.11-slim-bullseye
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

ARG TARGETPLATFORM
ENV IN_DOCKER=1
ENV GOSU_VERSION=1.16
LABEL org.bitcart.image=backend
ENV UV_COMPILE_BYTECODE=1
ENV UV_NO_CACHE=1
ENV UV_NO_SYNC=1

COPY bitcart /app
COPY scripts/docker-entrypoint.sh /usr/local/bin/
COPY --from=go-builder /go/bin/bitcart-cli /usr/local/bin/
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends iproute2 openssh-client build-essential python3-dev libffi-dev ca-certificates wget libjemalloc2 && \
    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" && \
    wget -qO /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" && \
    chmod +x /usr/local/bin/gosu && \
    groupadd --gid 1000 electrum && \
    useradd --uid 1000 --gid electrum --shell /bin/bash --create-home electrum && \
    uv sync --frozen --no-dev --group web --group production && \
    apt-get purge -y build-essential python3-dev libffi-dev wget && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*
ENV PYTHONUNBUFFERED=1 PYTHONMALLOC=malloc LD_PRELOAD=libjemalloc.so.2 MALLOC_CONF=background_thread:true,max_background_threads:1,metadata_thp:auto,dirty_decay_ms:80000,muzzy_decay_ms:80000
ENV PATH="/app/.venv/bin:$PATH"
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["sh"]

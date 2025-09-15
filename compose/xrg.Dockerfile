#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "generate-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM python:3.12-alpine AS base
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

ENV ELECTRUM_USER=electrum
ENV ELECTRUM_HOME=/home/$ELECTRUM_USER
ENV ELECTRUM_DIRECTORY=${ELECTRUM_HOME}/.oregano
ENV IN_DOCKER=1
ENV UV_COMPILE_BYTECODE=1
ENV UV_NO_CACHE=1
ENV UV_NO_SYNC=1
ENV XRG_HOST=0.0.0.0
LABEL org.bitcart.image=xrg-daemon

FROM base AS compile-image

COPY bitcart $ELECTRUM_HOME/site

RUN apk add git gcc python3-dev musl-dev automake autoconf libtool file git make libffi-dev openssl-dev rust cargo && \
    cd $ELECTRUM_HOME/site && \
    uv sync --frozen --no-dev --group xrg

FROM base AS build-image

RUN adduser -D $ELECTRUM_USER && \
    mkdir -p /data/ && \
    ln -sf /data/ $ELECTRUM_DIRECTORY && \
    chown ${ELECTRUM_USER} $ELECTRUM_DIRECTORY && \
    mkdir -p $ELECTRUM_HOME/site && \
    chown ${ELECTRUM_USER} $ELECTRUM_HOME/site && \
    apk add --no-cache libsecp256k1-dev git && \
    apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main jemalloc

COPY --from=compile-image --chown=electrum $ELECTRUM_HOME/site/.venv $ELECTRUM_HOME/.venv
COPY --from=compile-image --chown=electrum $ELECTRUM_HOME/site $ELECTRUM_HOME/site

ENV PYTHONUNBUFFERED=1 PYTHONMALLOC=malloc LD_PRELOAD=libjemalloc.so.2 MALLOC_CONF=background_thread:true,max_background_threads:1,metadata_thp:auto,dirty_decay_ms:80000,muzzy_decay_ms:80000
ENV PATH="$ELECTRUM_HOME/.venv/bin:$PATH"
USER $ELECTRUM_USER
WORKDIR $ELECTRUM_HOME/site

CMD ["python","daemons/xrg.py"]

#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "generate-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM python:3.11-alpine AS base

ENV ELECTRUM_USER electrum
ENV ELECTRUM_HOME /home/$ELECTRUM_USER
ENV ELECTRUM_DIRECTORY ${ELECTRUM_HOME}/.bitcart-xmr
ENV IN_DOCKER=1
ENV XMR_HOST 0.0.0.0
LABEL org.bitcart.image=xmr-daemon

FROM base AS compile-image

COPY bitcart $ELECTRUM_HOME/site

RUN apk add gcc python3-dev musl-dev automake autoconf libtool file git make libffi-dev && \
    cd $ELECTRUM_HOME/site && \
    pip3 install --no-warn-script-location --user -r requirements/deterministic/base.txt && \
    pip3 install --no-warn-script-location --user -r requirements/deterministic/daemons/xmr.txt

FROM base AS build-image

RUN adduser -D $ELECTRUM_USER && \
    mkdir -p /data/ && \
    ln -sf /data/ $ELECTRUM_DIRECTORY && \
    chown ${ELECTRUM_USER} $ELECTRUM_DIRECTORY && \
    mkdir -p $ELECTRUM_HOME/site && \
    chown ${ELECTRUM_USER} $ELECTRUM_HOME/site && \
    apk add --no-cache libsecp256k1-dev && \
    apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main jemalloc

COPY --from=compile-image --chown=electrum /root/.local $ELECTRUM_HOME/.local
COPY --from=compile-image --chown=electrum $ELECTRUM_HOME/site $ELECTRUM_HOME/site

ENV PYTHONUNBUFFERED=1 PYTHONMALLOC=malloc LD_PRELOAD=libjemalloc.so.2 MALLOC_CONF=background_thread:true,max_background_threads:1,metadata_thp:auto,dirty_decay_ms:80000,muzzy_decay_ms:80000
USER $ELECTRUM_USER
WORKDIR $ELECTRUM_HOME/site

CMD ["python","daemons/xmr.py"]

FROM python:3.9-alpine AS base

ENV ELECTRUM_USER electrum
ENV ELECTRUM_HOME /home/$ELECTRUM_USER
ENV ELECTRUM_DIRECTORY ${ELECTRUM_HOME}/.electron-cash
ENV IN_DOCKER=1
LABEL org.bitcartcc.image=bch-daemon

FROM base AS compile-image

COPY bitcart $ELECTRUM_HOME/site

RUN apk add gcc python3-dev musl-dev automake autoconf libtool file git make libffi-dev openssl-dev rust cargo && \
    cd $ELECTRUM_HOME/site && \
    pip3 install --no-warn-script-location --user -r requirements/deterministic/base.txt && \
    pip3 install --no-warn-script-location --user -r requirements/deterministic/daemons/bch.txt

FROM base AS build-image

RUN adduser -D $ELECTRUM_USER && \
    mkdir -p /data/ && \
    ln -sf /data/ $ELECTRUM_DIRECTORY && \
    chown ${ELECTRUM_USER} $ELECTRUM_DIRECTORY && \
    mkdir -p $ELECTRUM_HOME/site && \
    chown ${ELECTRUM_USER} $ELECTRUM_HOME/site && \
    apk add --no-cache libsecp256k1-dev

COPY --from=compile-image --chown=electrum /root/.local $ELECTRUM_HOME/.local
COPY --from=compile-image $ELECTRUM_HOME/site $ELECTRUM_HOME/site

USER $ELECTRUM_USER
WORKDIR $ELECTRUM_HOME/site
VOLUME /data

CMD ["python","daemons/bch.py"]

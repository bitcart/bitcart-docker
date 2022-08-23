#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "generate-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM python:3.9-alpine AS base

ENV ELECTRUM_USER electrum
ENV ELECTRUM_HOME /home/$ELECTRUM_USER
ENV ELECTRUM_DIRECTORY ${ELECTRUM_HOME}/.electrum-ltc
ENV IN_DOCKER=1
ENV LTC_HOST 0.0.0.0
LABEL org.bitcartcc.image=ltc-daemon

FROM base AS compile-image

COPY bitcart $ELECTRUM_HOME/site

RUN apk add python3-dev build-base libffi-dev && \
    cd $ELECTRUM_HOME/site && \
    pip3 install --no-warn-script-location --user -r requirements/deterministic/base.txt && \
    pip3 install --no-warn-script-location --user -r requirements/deterministic/daemons/ltc.txt

FROM base AS build-image

RUN adduser -D $ELECTRUM_USER && \
    mkdir -p /data/ && \
    ln -sf /data/ $ELECTRUM_DIRECTORY && \
    chown ${ELECTRUM_USER} $ELECTRUM_DIRECTORY && \
    mkdir -p $ELECTRUM_HOME/site && \
    chown ${ELECTRUM_USER} $ELECTRUM_HOME/site && \
    apk add --no-cache libsecp256k1-dev

COPY --from=compile-image --chown=electrum /root/.local $ELECTRUM_HOME/.local
COPY --from=compile-image --chown=electrum $ELECTRUM_HOME/site $ELECTRUM_HOME/site

USER $ELECTRUM_USER
WORKDIR $ELECTRUM_HOME/site

CMD ["python","daemons/ltc.py"]

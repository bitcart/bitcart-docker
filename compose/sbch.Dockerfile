#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "generate-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM python:3.9-alpine AS base

ENV ELECTRUM_USER electrum
ENV ELECTRUM_HOME /home/$ELECTRUM_USER
ENV ELECTRUM_DIRECTORY ${ELECTRUM_HOME}/.bitcart-sbch
ENV IN_DOCKER=1
ENV SBCH_HOST 0.0.0.0
LABEL org.bitcartcc.image=sbch-daemon

FROM base AS compile-image

COPY bitcart $ELECTRUM_HOME/site

RUN apk add gcc python3-dev musl-dev automake autoconf libtool file git make && \
    cd $ELECTRUM_HOME/site && \
    pip3 install --no-warn-script-location --user -r requirements/deterministic/base.txt && \
    pip3 install --no-warn-script-location --user -r requirements/deterministic/daemons/sbch.txt

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

CMD ["python","daemons/sbch.py"]

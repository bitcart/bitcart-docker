ARG COIN=btc

FROM bitcart/bitcart-$COIN:original

COPY plugins/daemon modules
COPY scripts/install-backend-plugins.sh /usr/local/bin/
RUN apk add --no-cache git && \
    sh /usr/local/bin/install-backend-plugins.sh
LABEL org.bitcart.plugins=true

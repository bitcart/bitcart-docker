ARG COIN

FROM bitcart/bitcart-${COIN}:original

COPY plugins/daemon modules
COPY scripts/install-backend-plugins.sh /usr/local/bin/
RUN sh install-backend-plugins.sh
LABEL org.bitcart.plugins=true

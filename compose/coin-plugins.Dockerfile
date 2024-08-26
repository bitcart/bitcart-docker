ARG COIN

FROM bitcart/bitcart-${COIN}:original

COPY plugins/daemon modules
COPY scripts/install-backend-plugins.sh /usr/local/bin/
RUN bash install-backend-plugins.sh
LABEL org.bitcart.plugins=true

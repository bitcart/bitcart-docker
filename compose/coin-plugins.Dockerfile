ARG COIN=btc

FROM bitcart/bitcart-$COIN:original

COPY plugins/daemon modules
COPY scripts/install-daemon-plugins.sh /usr/local/bin/
RUN sh /usr/local/bin/install-daemon-plugins.sh
LABEL org.bitcart.plugins=true

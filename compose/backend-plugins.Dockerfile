FROM bitcart/bitcart:original

COPY plugins/backend modules
COPY scripts/install-backend-plugins.sh /usr/local/bin/
RUN bash install-backend-plugins.sh
LABEL org.bitcart.plugins=true

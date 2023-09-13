FROM bitcart/bitcart-store:original

USER root
COPY plugins/store modules
COPY scripts/install-ui-plugins.sh /usr/local/bin/
RUN install-ui-plugins.sh
USER node
LABEL org.bitcart.plugins=true

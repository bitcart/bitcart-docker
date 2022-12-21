FROM bitcartcc/bitcart-store:original

USER root
COPY plugins/store modules
COPY scripts/install-ui-plugins.sh /usr/local/bin/
RUN install-ui-plugins.sh
USER node
LABEL org.bitcartcc.plugins=true

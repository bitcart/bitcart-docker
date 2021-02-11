FROM python:3.7-slim-buster

ENV IN_DOCKER=1
LABEL org.bitcartcc.image=backend

COPY bitcart /app
COPY scripts/docker-entrypoint.sh /usr/local/bin/
WORKDIR /app
RUN groupadd --gid 1000 electrum && \
    useradd --uid 1000 --gid electrum --shell /bin/bash --create-home electrum && \
    pip install -r requirements.txt && \
    pip install -r requirements/production.txt && \
    rm -rf /root/.cache/pip
USER electrum
VOLUME /app/images
CMD ["sh"]

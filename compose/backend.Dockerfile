FROM python:3.7-slim-buster

ENV IN_DOCKER=1
LABEL org.bitcartcc.image=backend

COPY bitcart /app
COPY scripts/docker-entrypoint.sh /usr/local/bin/
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends iproute2 openssh-client build-essential python3-dev libffi-dev && \
    groupadd --gid 1000 electrum && \
    useradd --uid 1000 --gid electrum --shell /bin/bash --create-home electrum && \
    # remove hashes to be able to use piwheels
    cd requirements/deterministic && find -name "*.txt" -exec sed -i '/--hash/d' {} \; && cd ../.. && \
    pip install --extra-index-url https://www.piwheels.org/simple -r requirements/deterministic/web.txt && \
    pip install --extra-index-url https://www.piwheels.org/simple -r requirements/deterministic/production.txt && \
    apt-get purge -y build-essential python3-dev libffi-dev && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /root/.cache/pip
USER electrum
CMD ["sh"]

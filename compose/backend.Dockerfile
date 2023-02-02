FROM golang:1.18-alpine AS go-builder

RUN CGO_ENABLED=0 go install -ldflags '-X main.Version=docker' github.com/bitcartcc/bitcart-cli@master

FROM python:3.9-slim-bullseye

ARG TARGETPLATFORM
ENV IN_DOCKER=1
ENV GOSU_VERSION 1.14
LABEL org.bitcartcc.image=backend

COPY bitcart /app
COPY scripts/docker-entrypoint.sh /usr/local/bin/
COPY --from=go-builder /go/bin/bitcart-cli /usr/local/bin/
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends iproute2 openssh-client build-essential python3-dev libffi-dev ca-certificates wget && \
    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" && \
    wget -qO /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" && \
    chmod +x /usr/local/bin/gosu && \
    groupadd --gid 1000 electrum && \
    useradd --uid 1000 --gid electrum --shell /bin/bash --create-home electrum && \
    pip install -r requirements/deterministic/web.txt && \
    pip install -r requirements/deterministic/production.txt && \
    apt-get purge -y build-essential python3-dev libffi-dev wget && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /root/.cache/pip
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["sh"]

FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS agent-build
ARG TARGETARCH
ARG AGENT_OS="linux darwin"
WORKDIR /src
COPY host-agent/ ./
RUN for os in $AGENT_OS; do \
        if go tool dist list | grep -qx "$os/$TARGETARCH"; then \
            CGO_ENABLED=0 GOOS=$os GOARCH=$TARGETARCH go build -trimpath -ldflags "-s -w" \
                -o "/out/bitcart-agent-$os" . || exit 1; \
        fi; \
    done && \
    touch -d @0 /out /out/*

FROM python:3.12-alpine
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
LABEL org.bitcart.image=docker-compose-generator
WORKDIR /app
COPY pyproject.toml uv.lock /app/
COPY generator /app/generator
ENV UV_COMPILE_BYTECODE=1
ENV UV_NO_CACHE=1
ENV UV_NO_SYNC=1
RUN uv sync --frozen --no-dev
ENV PATH="/app/.venv/bin:$PATH"
COPY --from=agent-build /out/ /agent/
ENTRYPOINT [ "python3", "-m", "generator"]

FROM python:3.11-alpine
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
LABEL org.bitcart.image=docker-compose-generator
COPY . /app/generator
WORKDIR /app
ENV UV_COMPILE_BYTECODE=1
ENV UV_NO_CACHE=1
ENV UV_NO_SYNC=1
RUN uv sync --frozen --no-dev
ENTRYPOINT [ "python3", "-m", "generator"]

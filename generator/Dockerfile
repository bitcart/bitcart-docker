FROM python:3.11-alpine
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
ENTRYPOINT [ "python3", "-m", "generator"]

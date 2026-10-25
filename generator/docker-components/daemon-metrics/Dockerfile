FROM python:3.12-slim

WORKDIR /app

RUN pip install --no-cache-dir aiohttp prometheus-client

COPY exporter.py .

EXPOSE 8000

CMD ["python", "exporter.py"]

FROM python:3.11-alpine
LABEL org.bitcart.image=docker-compose-generator
COPY . /app/generator
WORKDIR /app
RUN pip3 install --no-cache-dir -r generator/requirements.txt
ENTRYPOINT [ "python3", "-m", "generator"]

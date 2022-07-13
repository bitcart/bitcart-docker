FROM python:3.9-alpine
LABEL org.bitcartcc.image=docker-compose-generator
COPY . /app/generator
WORKDIR /app
RUN pip3 install -r generator/requirements.txt
ENTRYPOINT [ "python3", "-m", "generator"]

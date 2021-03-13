FROM python:3.7-alpine
LABEL org.bitcartcc.image=docker-compose-generator
COPY . /app/generator
WORKDIR /app
RUN pip3 install -r generator/requirements.txt
ENV IN_DOCKER=true
ENTRYPOINT [ "python3", "-m", "generator"]
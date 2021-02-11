FROM python:3.7-alpine
LABEL org.bitcartcc.image=docker-compose-generator
COPY . /app/
WORKDIR /app
RUN pip3 install oyaml
ENV IN_DOCKER=true
ENTRYPOINT [ "python3", "main.py"]
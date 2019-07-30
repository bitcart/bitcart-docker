FROM python:3.6-alpine

ENV ELECTRUM_USER electrum
ENV ELECTRUM_HOME /home/$ELECTRUM_USER

RUN adduser -D $ELECTRUM_USER && \
    mkdir -p ${ELECTRUM_HOME}/.electrum/ /data/ && \
    ln -sf ${ELECTRUM_HOME}/.electrum/ /data/ && \
    chown ${ELECTRUM_USER} ${ELECTRUM_HOME}/.electrum && \
    mkdir -p $ELECTRUM_HOME/site && \
    chown ${ELECTRUM_USER} $ELECTRUM_HOME/site

COPY bitcart $ELECTRUM_HOME/site
COPY scripts/docker-entrypoint.sh /usr/local/bin/

RUN apk add --virtual build-deps --no-cache postgresql-dev gcc python3-dev musl-dev jpeg-dev \
    zlib-dev \
    freetype-dev \
    lcms2-dev \
    openjpeg-dev \
    tiff-dev \
    tk-dev \
    tcl-dev \
    harfbuzz-dev \
    fribidi-dev && \
    apk add postgresql-libs jpeg openjpeg tiff && \
    cd $ELECTRUM_HOME/site && \
    pip3 install -r requirements.txt && \
    pip3 install -r requirements/production.txt && \
    apk del build-deps

USER $ELECTRUM_USER
WORKDIR $ELECTRUM_HOME/site
VOLUME /data

CMD ["sh"]

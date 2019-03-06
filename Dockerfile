FROM python:3.6-alpine


RUN apk add --no-cache gnupg mariadb-connector-c-dev gcc musl-dev jpeg-dev \
                       zlib-dev \
                       freetype-dev \
                       lcms2-dev \
                       openjpeg-dev \
                       tiff-dev \
                       tk-dev \
                       tcl-dev \
                       harfbuzz-dev \
                       fribidi-dev


ENV ELECTRUM_VERSION $VERSION
ENV ELECTRUM_USER electrum
ENV ELECTRUM_PASSWORD electrumz
ENV ELECTRUM_HOME /home/$ELECTRUM_USER

COPY scripts/electrum_version.py /usr/local/bin/

RUN adduser -D $ELECTRUM_USER && \
    pip3 install -U requests && \
    python3 /usr/local/bin/electrum_version.py

RUN mkdir -p ${ELECTRUM_HOME}/.electrum/ /data/ && \
	ln -sf ${ELECTRUM_HOME}/.electrum/ /data/ && \
	chown ${ELECTRUM_USER} ${ELECTRUM_HOME}/.electrum 

RUN mkdir -p $ELECTRUM_HOME/site && chown ${ELECTRUM_USER} $ELECTRUM_HOME/site
COPY bitcart $ELECTRUM_HOME/site
RUN cd $ELECTRUM_HOME/site && \
    pip3 install -r requirements.txt

USER $ELECTRUM_USER
WORKDIR $ELECTRUM_HOME/site
VOLUME /data

COPY scripts/docker-entrypoint.sh /usr/local/bin/

CMD ["electrum"]

FROM python:3.6-alpine

ENV ELECTRUM_USER electrum
ENV ELECTRUM_HOME /home/$ELECTRUM_USER
ENV IN_DOCKER=1
LABEL org.bitcartcc.image=ltc-daemon

RUN adduser -D $ELECTRUM_USER && \
    mkdir -p ${ELECTRUM_HOME}/.electrum/ /data/ && \
    ln -sf ${ELECTRUM_HOME}/.electrum/ /data/ && \
    chown ${ELECTRUM_USER} ${ELECTRUM_HOME}/.electrum && \
    mkdir -p $ELECTRUM_HOME/site && \
    chown ${ELECTRUM_USER} $ELECTRUM_HOME/site

COPY bitcart $ELECTRUM_HOME/site

RUN apk add --virtual build-deps --no-cache gcc python3-dev musl-dev automake autoconf libtool file git make openssl-dev && \
    git clone https://github.com/bitcoin/secp256k1 && \
    cd secp256k1 && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install && \
    cd .. && \
    rm -rf secp256k1 && \
    cd $ELECTRUM_HOME/site && \
    pip3 install -r requirements/base.txt && \
    pip3 install -r requirements/daemons/ltc.txt && \
    apk del build-deps

USER $ELECTRUM_USER
WORKDIR $ELECTRUM_HOME/site
VOLUME /data

CMD ["python","daemons/ltc.py"]

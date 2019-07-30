FROM python:3.6-alpine

ENV ELECTRUM_USER electrum
ENV ELECTRUM_HOME /home/$ELECTRUM_USER
ENV IN_DOCKER=1

RUN adduser -D $ELECTRUM_USER && \
    mkdir -p ${ELECTRUM_HOME}/.electrum/ /data/ && \
    ln -sf ${ELECTRUM_HOME}/.electrum/ /data/ && \
    chown ${ELECTRUM_USER} ${ELECTRUM_HOME}/.electrum && \
    mkdir -p $ELECTRUM_HOME/site && \
    chown ${ELECTRUM_USER} $ELECTRUM_HOME/site

COPY bitcart $ELECTRUM_HOME/site

RUN cd $ELECTRUM_HOME/site && \
    pip3 install -r requirements/base.txt && \
    pip3 install -r requirements/daemons/btc.txt

USER $ELECTRUM_USER
WORKDIR $ELECTRUM_HOME/site
VOLUME /data

CMD ["python","daemons/btc.py"]

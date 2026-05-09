FROM debian:trixie-slim

ARG VERSION_TAG=3.2.8
ARG EXPECTED_MD5=cc11aac80688bd6b42e382ab02127a0e

ENV ALGO="kheavyhash"
ENV POOL_ADDRESS="stratum+tcp://heavyhash.eu.mine.zergpool.com:5137"
ENV WALLET_USER="1Fyq3JegvpKDrfcEgyxJdQGfgZZjhDJ18P"
ENV WORKER_NAME=""
ENV POOL_PASSWORD="c=BTC"
ENV EXTRAS="--disable-gpu --api-enable --api-port 21550"
ENV LOG_LEVEL="info"
ENV HSA_ENABLE_SDMA=0
ENV ROCR_VISIBLE_DEVICES=0
ENV HIP_VISIBLE_DEVICES=0

RUN apt-get -y update \
    && apt-get -y upgrade \
    && apt-get -y install curl wget ca-certificates tar \
    && update-ca-certificates \
    && cd /opt \
    && VERSION_STRING=$(echo "$VERSION_TAG" | tr '.' '-') \
    && wget -nv https://github.com/doktor83/SRBMiner-Multi/releases/download/${VERSION_TAG}/SRBMiner-Multi-${VERSION_STRING}-Linux.tar.gz -O SRBMiner.tar.gz \
    && echo "${EXPECTED_MD5}  SRBMiner.tar.gz" | md5sum -c - \
    && tar xf SRBMiner.tar.gz \
    && rm -rf SRBMiner.tar.gz \
    && mv /opt/SRBMiner-Multi-${VERSION_STRING}/ /opt/SRBMiner-Multi/ \
    && groupadd -r srbminer && useradd -r -g srbminer -d /opt/SRBMiner-Multi -s /bin/bash srbminer \
    && groupadd -fr video && groupadd -fr render \
    && usermod -aG video,render srbminer \
    && apt-get -y autoremove --purge \
    && apt-get -y clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

WORKDIR /opt/SRBMiner-Multi/
COPY start_zergpool.sh .
RUN chmod +x start_zergpool.sh && chown srbminer:srbminer start_zergpool.sh

USER srbminer

EXPOSE 21550

ENTRYPOINT ["./start_zergpool.sh"]

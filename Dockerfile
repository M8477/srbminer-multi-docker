FROM debian:trixie-slim

ARG VERSION_TAG=2.9.8

ENV ALGO="kheavyhash"
ENV POOL_ADDRESS="stratum+tcp://heavyhash.eu.mine.zergpool.com:5137"
ENV WALLET_USER="1Fyq3JegvpKDrfcEgyxJdQGfgZZjhDJ18P"
ENV PASSWORD="c=BTC"
ENV EXTRAS="--disable-gpu --api-enable --api-port 21550"
ENV LOG_LEVEL="info"

RUN apt-get -y update \
    && apt-get -y upgrade \
    && apt-get -y install curl wget ca-certificates xz-utils tar \
    && update-ca-certificates \
    && cd /opt \
    && VERSION_STRING=$(echo "$VERSION_TAG" | tr '.' '-') \
    && wget -nv https://github.com/doktor83/SRBMiner-Multi/releases/download/${VERSION_TAG}/SRBMiner-Multi-${VERSION_STRING}-Linux.tar.xz -O SRBMiner.tar.xz \
    && wget -nv https://github.com/doktor83/SRBMiner-Multi/releases/download/${VERSION_TAG}/SRBMiner-Multi-${VERSION_STRING}-Linux.tar.xz.sha256 -O SRBMiner.tar.xz.sha256 \
    && echo "$(cat SRBMiner.tar.xz.sha256 | awk '{print $1}')  SRBMiner.tar.xz" | sha256sum -c - \
    && tar xf SRBMiner.tar.xz \
    && rm -rf SRBMiner.tar.xz SRBMiner.tar.xz.sha256 \
    && mv /opt/SRBMiner-Multi-${VERSION_STRING}/ /opt/SRBMiner-Multi/ \
    && groupadd -r srbminer && useradd -r -g srbminer -d /opt/SRBMiner-Multi -s /bin/bash srbminer \
    && apt-get -y autoremove --purge \
    && apt-get -y clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

WORKDIR /opt/SRBMiner-Multi/
COPY start_zergpool.sh .
RUN chmod +x start_zergpool.sh && chown srbminer:srbminer start_zergpool.sh

USER srbminer

EXPOSE 21550

ENTRYPOINT ["./start_zergpool.sh"]

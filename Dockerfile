FROM debian:trixie-slim

ARG VERSION_TAG=3.5.0
ARG EXPECTED_MD5=20a98f68677212e10d795acf6c5d835e

ENV ALGO="autolykos2;randomx"
ENV POOL_ADDRESS="stratum+tcp://autolykos.unmineable.com:3333"
ENV POOL_ADDRESS_CPU="stratum+tcp://rx.unmineable.com:3333"
ENV WALLET_USER="BTC:1Fyq3JegvpKDrfcEgyxJdQGfgZZjhDJ18P"
ENV WORKER_NAME=""
ENV POOL_PASSWORD="x"
ENV EXTRAS="--disable-gpu --api-enable --api-port 21550 --extended-log"
ENV LOG_LEVEL="info"
ENV DRY_RUN="false"
ENV VERSION_TAG=$VERSION_TAG
ENV LD_LIBRARY_PATH=/opt/rocm/lib
ENV HSA_ENABLE_SDMA=0
ENV ROCR_VISIBLE_DEVICES=0
ENV HIP_VISIBLE_DEVICES=0


RUN apt-get -y update \
    && apt-get -y upgrade \
    && apt-get -y install curl wget ca-certificates tar procps libdrm2 libdrm-amdgpu1 libnuma1 ocl-icd-opencl-dev \
    && update-ca-certificates \
    && cd /opt \
    && VERSION_STRING=$(echo "$VERSION_TAG" | tr '.' '-') \
    && wget -nv https://github.com/doktor83/SRBMiner-Multi/releases/download/${VERSION_TAG}/SRBMiner-Multi-${VERSION_STRING}-Linux.tar.gz -O SRBMiner.tar.gz \
    && echo "${EXPECTED_MD5}  SRBMiner.tar.gz" | md5sum -c - \
    && tar xf SRBMiner.tar.gz \
    && rm -rf SRBMiner.tar.gz \
    && mv /opt/SRBMiner-Multi-${VERSION_STRING}/ /opt/SRBMiner-Multi/ \
    && chown -R nobody:nogroup /opt/SRBMiner-Multi/ \
    && groupadd -r srbminer && useradd -r -g srbminer -d /opt/SRBMiner-Multi -s /bin/bash srbminer \
    && chown -R srbminer:srbminer /opt/SRBMiner-Multi/ \
    && groupadd -fr video && groupadd -fr render \
    && usermod -aG video,render srbminer \
    && mkdir -p /etc/OpenCL/vendors \
    && echo "/opt/rocm/lib/libamdocl64.so" > /etc/OpenCL/vendors/amdocl64.icd \
    && apt-get -y autoremove --purge \
    && apt-get -y clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* \
    && rm -f /.dockerenv

WORKDIR /opt/SRBMiner-Multi/
COPY start_zergpool.sh .
RUN chmod +x start_zergpool.sh

EXPOSE 21550

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD pgrep -x SRBMiner-MULTI > /dev/null || exit 1

ENTRYPOINT ["./start_zergpool.sh"]

# Uncomment if building locally...
# FROM debian:stretch

FROM --platform=${TARGETPLATFORM:-linux/amd64} debian:bookworm-slim

ARG BUILD_DATE
ARG VERSION
ARG VCS_REF
ARG TARGETPLATFORM

LABEL org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.version=$VERSION \
  org.label-schema.vcs-ref=$VCS_REF

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        git \
        build-essential \
        cmake \
        jq \
        mosquitto-clients \
    && rm -rf /var/lib/apt/lists/*

ADD sources/ /opt/sources/
ADD config/ /etc/inverter/

# Corregimos la ruta de compilación (añadimos sources/)
RUN cd /opt/sources/inverter-cli && \
    mkdir -p bin && cmake . && make && mv inverter_poller bin/

# Corregimos la ruta de compilación del segundo binario (que falta en tu archivo)
RUN cd /opt/sources/inverter-mqtt && \
    cmake . && make

HEALTHCHECK \
    --interval=30s \
    --timeout=10s \
    --start-period=1m \
    --retries=3 \
  CMD /opt/sources/healthcheck

WORKDIR /opt/sources
ENTRYPOINT ["/bin/bash", "/opt/sources/inverter-mqtt/entrypoint.sh"]

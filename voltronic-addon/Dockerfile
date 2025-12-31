# Uncomment if building locally...

ARG BUILD_FROM
FROM ${BUILD_FROM}

ARG BUILD_DATE
ARG VERSION
ARG VCS_REF
ARG TARGETPLATFORM

LABEL org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.version=$VERSION \
  org.label-schema.vcs-ref=$VCS_REF

RUN apk add --no-cache \
        curl \
        git \
        build-base \
        cmake \
        jq \
        mosquitto-clients

ADD sources/ /opt/
RUN mkdir -p /opt/inverter

# Copiar archivos de configuración y scripts a las rutas esperadas
ADD sources/inverter-cli/inverter.conf /opt/inverter/inverter.conf
ADD sources/inverter-mqtt/mqtt.json /opt/inverter/mqtt.json
ADD sources/inverter-mqtt/ /opt/inverter/
RUN chmod +x /opt/inverter/*.sh

# Compilar inverter_poller y moverlo a /usr/bin
# Compilar inverter_poller y moverlo a /usr/bin
RUN cd /opt/inverter-cli && \
    cmake . && make -j$(nproc) && \
    cp inverter_poller /usr/bin/inverter_poller


HEALTHCHECK \
    --interval=30s \
    --timeout=10s \
    --start-period=1m \
    --retries=3 \
  CMD /opt/healthcheck

WORKDIR /opt
ENTRYPOINT ["/bin/bash", "/opt/inverter-mqtt/entrypoint.sh"]

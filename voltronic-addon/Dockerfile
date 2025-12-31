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

RUN apt-get update && apt-get install -y \
        curl \
        git \
        build-essential \
        cmake \
        jq \
        mosquitto-clients

ADD sources/ /opt/
RUN mkdir -p /etc/inverter
ADD sources/inverter-cli/inverter.conf /etc/inverter/inverter.conf

RUN cd /opt/inverter-cli && \
    mkdir bin && cmake . && make && mv inverter_poller bin/

HEALTHCHECK \
    --interval=30s \
    --timeout=10s \
    --start-period=1m \
    --retries=3 \
  CMD /opt/healthcheck

WORKDIR /opt
ENTRYPOINT ["/bin/bash", "/opt/inverter-mqtt/entrypoint.sh"]

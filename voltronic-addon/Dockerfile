FROM ghcr.io/home-assistant/aarch64-base:latest

# 1. Instalamos dependencias para compilar y ejecutar
RUN apk add --no-cache \
    build-essential \
    cmake \
    git \
    mosquitto-clients \
    bash \
    g++ \
    make

# 2. Copiamos los archivos DIRECTAMENTE en /opt/
# Esto hará que /opt/inverter-cli y /opt/inverter-mqtt existan
COPY sources/ /opt/
COPY config/ /etc/inverter/

# 3. Compilamos el poller (inverter-cli)
RUN cd /opt/inverter-cli && \
    cmake . && \
    make && \
    cp inverter_poller /usr/bin/

# 4. Preparamos el entrypoint y los scripts
RUN chmod +x /opt/inverter-mqtt/entrypoint.sh && \
    chmod +x /opt/inverter-mqtt/mqtt-subscriber.sh

WORKDIR /opt/inverter-mqtt
ENTRYPOINT ["/bin/bash", "/opt/inverter-mqtt/entrypoint.sh"]

FROM ghcr.io/home-assistant/aarch64-base:latest

# 1. Instalamos dependencias (jq es vital para leer tu configuración)
RUN apk add --no-cache \
    build-base \
    cmake \
    git \
    mosquitto-clients \
    bash \
    jq

# 2. Copiamos los archivos de sources a /opt/
# Esto ya incluye tu mqtt.json e inverter.conf si los pusiste ahí
COPY sources/ /opt/

# 3. Compilamos el poller
RUN cd /opt/inverter-cli && \
    cmake . && \
    make && \
    cp inverter_poller /usr/bin/

# 4. Damos permisos de ejecución a todos los scripts
RUN chmod +x /opt/inverter-mqtt/*.sh

# 5. Directorio de trabajo y arranque
WORKDIR /opt/inverter-mqtt
ENTRYPOINT ["/bin/bash", "/opt/inverter-mqtt/entrypoint.sh"]

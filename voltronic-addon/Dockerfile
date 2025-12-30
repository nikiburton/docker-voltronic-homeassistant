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
# Primero copiamos SOLO la carpeta del poller y compilamos
COPY sources/inverter-cli/ /opt/inverter-cli/
RUN cd /opt/inverter-cli && cmake . && make -j$(nproc) && cp inverter_poller /usr/bin/

# Después copiamos el resto de scripts (que es lo que más solemos cambiar)
COPY sources/inverter-mqtt/ /opt/inverter-mqtt/
RUN chmod +x /opt/inverter-mqtt/*.sh

# 5. Directorio de trabajo y arranque
WORKDIR /opt/inverter-mqtt
ENTRYPOINT ["/bin/bash", "/opt/inverter-mqtt/entrypoint.sh"]

FROM --platform=${TARGETPLATFORM:-linux/amd64} debian:bookworm-slim

# Instalamos las herramientas necesarias
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    build-essential \
    cmake \
    jq \
    mosquitto-clients \
    && rm -rf /var/lib/apt/lists/*

# Creamos la carpeta y copiamos los archivos
RUN mkdir -p /opt/sources
ADD sources/ /opt/sources/
ADD config/ /etc/inverter/

# 1. Compilamos SOLAMENTE el inverter-cli (el poller)
# Usamos el fix para asegurar que se instale en el sistema
RUN cd /opt/sources/inverter-cli && \
    cmake . && \
    make && \
    cp inverter_poller /usr/bin/

# 2. Damos permisos al entrypoint
# Nota: La ruta suele ser /opt/sources/inverter-mqtt/entrypoint.sh
RUN chmod +x /opt/sources/inverter-mqtt/entrypoint.sh

# 3. Salud
HEALTHCHECK --interval=30s --timeout=10s --start-period=1m --retries=3 \
    CMD mosquitto_pub -h localhost -t "status/health" -m "OK" || exit 1

WORKDIR /opt/sources
ENTRYPOINT ["/bin/bash", "/opt/sources/inverter-mqtt/entrypoint.sh"]

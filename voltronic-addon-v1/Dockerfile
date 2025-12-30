FROM ubuntu:22.04

# Dependencias
RUN apt-get update && apt-get install -y \
    build-essential \
    mosquitto-clients \
    jq \
    libncurses5-dev \
    && rm -rf /var/lib/apt/lists/*

# Crear directorio de addon
WORKDIR /opt/inverter-mqtt
COPY inverter-mqtt/ ./inverter-mqtt/

# Copiar scripts
COPY run.sh /run.sh
RUN chmod +x /run.sh

# Punto de entrada
CMD [ "/run.sh" ]


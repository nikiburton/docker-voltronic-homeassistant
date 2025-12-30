FROM ghcr.io/home-assistant/aarch64-base:latest

# 1. Instalamos dependencias (Añadimos jq que es imprescindible)
RUN apk add --no-cache \
    build-base \
    cmake \
    git \
    mosquitto-clients \
    bash \
    jq

# 2. Copiamos los archivos
COPY sources/ /opt/
# Si ya moviste mqtt.json e inverter.conf fuera de aquí, esta línea no hará nada malo, 
# pero asegúrate de que la carpeta 'config/' no esté vacía en GitHub o Docker podría dar error.
COPY config/ /etc/inverter/ 

# 3. Compilamos el poller
RUN cd /opt/inverter-cli && \
    cmake . && \
    make && \
    cp inverter_poller /usr/bin/

# 4. Preparamos permisos (Damos permiso a TODOS los .sh para evitar fallos de ejecución)
RUN chmod +x /opt/inverter-mqtt/*.sh

WORKDIR /opt/inverter-mqtt
ENTRYPOINT ["/bin/bash", "/opt/inverter-mqtt/entrypoint.sh"]

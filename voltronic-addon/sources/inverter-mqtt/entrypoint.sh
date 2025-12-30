#!/usr/bin/with-contenv bash
set -e

echo "--- DETALLE DE DISPOSITIVOS USB ---"
lsusb
echo "------------------------------------"

CONFIG_PATH=/data/options.json
MQTT_HOST=$(jq -r '.mqtt_host' $CONFIG_PATH)
MQTT_USER=$(jq -r '.mqtt_user' $CONFIG_PATH)
MQTT_PASS=$(jq -r '.mqtt_password' $CONFIG_PATH)
MQTT_PORT=$(jq -r '.mqtt_port' $CONFIG_PATH)
DEVICE=$(jq -r '.device' $CONFIG_PATH)

JSON_FILE="/opt/inverter-mqtt/mqtt.json"
SCRIPTS_DIR="/opt/inverter-mqtt"
POLLER_BIN="/usr/bin/inverter_poller"
CONF_FILE="/opt/inverter-mqtt/inverter.conf"

echo "Usando dispositivo HID: $DEVICE"

# 1. LIBERACIÓN DEL DISPOSITIVO
echo "Intentando liberar $DEVICE del driver usbhid..."
mount -o remount,rw /sys 2>/dev/null || true

for dev in /sys/bus/usb/drivers/usbhid/*:*; do
    if [ -e "$dev" ]; then
        echo "Desvinculando $(basename $dev)..."
        echo "$(basename $dev)" > /sys/bus/usb/drivers/usbhid/unbind 2>/dev/null || echo "Aviso: No se pudo desvincular $(basename $dev)"
    fi
done

# 2. Comprobación del dispositivo
if [ ! -e "$DEVICE" ]; then
    echo "ERROR: Dispositivo $DEVICE no existe"
    ls -l /dev/hidraw* || echo "No hay dispositivos hidraw disponibles"
    exit 1
fi

# 3. Configuración de MQTT JSON
if [ -f "$JSON_FILE" ]; then
    echo "Configurando $JSON_FILE..."
    sed -i "s@\"server\": \".*\"@\"server\": \"$MQTT_HOST\"@g" "$JSON_FILE"
    sed -i "s@\"port\": \".*\"@\"port\": \"$MQTT_PORT\"@g" "$JSON_FILE"
    sed -i "s@\"username\": \".*\"@\"username\": \"$MQTT_USER\"@g" "$JSON_FILE"
    sed -i "s@\"password\": \".*\"@\"password\": \"$MQTT_PASS\"@g" "$JSON_FILE"
fi
# ... (después de los comandos sed) ...

if [ -f "$JSON_FILE" ]; then
    echo "--- VERIFICACIÓN DE CONFIGURACIÓN MQTT ---"
    # Mostramos el archivo pero ocultamos la contraseña por seguridad
    cat "$JSON_FILE" | grep -v '"password"' 
    echo "------------------------------------------"
fi

export MQTT_HOST MQTT_USER MQTT_PASS MQTT_PORT DEVICE

cd "$SCRIPTS_DIR"
echo "Iniciando procesos..."

# Ejecutar el inicializador de MQTT
# 4. PREPARACIÓN DEL INVERTER.CONF
cd "$SCRIPTS_DIR"
if [ -f "$CONF_FILE" ]; then
    echo "Actualizando $CONF_FILE con el dispositivo $DEVICE..."
    sed -i "s|^device=.*|device=$DEVICE|" "$CONF_FILE"
    # Copiamos a rutas alternativas por seguridad
    cp "$CONF_FILE" /usr/bin/inverter.conf
    cp "$CONF_FILE" /etc/inverter.conf
fi

# 5. INICIO DE PROCESOS MQTT (Sin bloqueo)
chmod +x "$POLLER_BIN"
chmod +x ./*.sh

echo "Iniciando procesos de MQTT..."

# Ejecutamos el Auto-Discovery (mqtt-init.sh)
# No usamos strace aquí para que no bloquee en segundo plano
/bin/bash ./mqtt-init.sh &

# Lanzamos el suscriptor en segundo plano
/bin/bash ./mqtt-subscriber.sh &

# Iniciamos el loop de actualización cada 300s para el init (opcional)
watch -n 300 /bin/bash ./mqtt-init.sh > /dev/null 2>&1 &

# 6. LOOP PRINCIPAL DE DATOS
# Este comando se queda ejecutándose y es el que mantiene el addon vivo
echo "Ejecutando loop de datos (mqtt-push.sh)..."
exec watch -n 30 /bin/bash ./mqtt-push.sh

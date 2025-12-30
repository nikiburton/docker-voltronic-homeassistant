#!/bin/bash
#
# Simple script to register the MQTT topics when the container starts for the first time...

# --- RUTAS CORREGIDAS ---
BIN="/usr/bin/inverter_poller"
CONF="/opt/inverter-mqtt/inverter.conf"
MQTT_CONF="/opt/inverter-mqtt/mqtt.json"

# Verificar que los archivos existen antes de seguir
if [ ! -f "$BIN" ]; then echo "ERROR: No se encuentra el binario en $BIN"; exit 1; fi
if [ ! -f "$CONF" ]; then echo "ERROR: No se encuentra el config en $CONF"; exit 1; fi
if [ ! -f "$MQTT_CONF" ]; then echo "ERROR: No se encuentra el mqtt.json en $MQTT_CONF"; exit 1; fi

# Leer configuración de MQTT
MQTT_SERVER=$(jq -r '.server' $MQTT_CONF)
MQTT_PORT=$(jq -r '.port' $MQTT_CONF)
MQTT_USERNAME=$(jq -r '.username' $MQTT_CONF)
MQTT_PASSWORD=$(jq -r '.password' $MQTT_CONF)
MQTT_TOPIC=$(jq -r '.topic' $MQTT_CONF)
MQTT_DEVICENAME=$(jq -r '.devicename' $MQTT_CONF)
MQTT_CLIENTID=$(jq -r '.clientid' $MQTT_CONF)

echo "Iniciando Auto-Discovery de MQTT en $MQTT_SERVER para el dispositivo $MQTT_DEVICENAME..."

echo "DEBUG: Generando mensaje de Discovery para un sensor..."
echo "Topic: homeassistant/sensor/$MQTT_DEVICENAME/ac_grid_voltage/config"
echo "Payload: {\"name\": \"$MQTT_DEVICENAME AC Grid Voltage\", \"state_topic\": \"$MQTT_TOPIC/sensor/$MQTT_DEVICENAME/AC_grid_voltage\", \"unit_of_measurement\": \"V\", \"device_class\": \"voltage\"}"

# Prueba de envío con salida de error visible
mosquitto_pub -h "$MQTT_SERVER" -p "$MQTT_PORT" -u "$MQTT_USERNAME" -P "$MQTT_PASSWORD" \
  -t "homeassistant/sensor/$MQTT_DEVICENAME/ac_grid_voltage/config" \
  -m "{\"name\": \"$MQTT_DEVICENAME AC Grid Voltage\", \"state_topic\": \"$MQTT_TOPIC/sensor/$MQTT_DEVICENAME/AC_grid_voltage\", \"unit_of_measurement\": \"V\", \"device_class\": \"voltage\"}" \
  -d # El parámetro -d mostrará si hay errores de conexión

# Ejecutar el poller para obtener los datos actuales
# Usamos la ruta absoluta del binario y el config
DATA=$($BIN -d)

registerTopic () {
    mosquitto_pub -h "$MQTT_SERVER" -p "$MQTT_PORT" -u "$MQTT_USERNAME" -P "$MQTT_PASSWORD" \
        -i "$MQTT_CLIENTID" \
        -t "$MQTT_TOPIC/sensor/$MQTT_DEVICENAME"_$1/config" \
        -m "{
            \"name\": \""$MQTT_DEVICENAME"_$1\",
            \"unit_of_measurement\": \"$2\",
            \"state_topic\": \"$MQTT_TOPIC/sensor/"$MQTT_DEVICENAME"_$1\",
            \"icon\": \"mdi:$3\"
        }"
}

registerInverterRawCMD () {
    mosquitto_pub \
        -h "$MQTT_SERVER" \
        -p "$MQTT_PORT" \
        -u "$MQTT_USERNAME" \
        -P "$MQTT_PASSWORD" \
        -i "$MQTT_CLIENTID" \
        -t "$MQTT_TOPIC/sensor/$MQTT_DEVICENAME/config" \
        -m "{
            \"name\": \""$MQTT_DEVICENAME"\",
            \"state_topic\": \"$MQTT_TOPIC/sensor/$MQTT_DEVICENAME\"
        }"
}

registerTopic "Inverter_mode" "" "solar-power" # 1 = Power_On, 2 = Standby, 3 = Line, 4 = Battery, 5 = Fault, 6 = Power_Saving, 7 = Unknown
registerTopic "AC_grid_voltage" "V" "power-plug"
registerTopic "AC_grid_frequency" "Hz" "current-ac"
registerTopic "AC_out_voltage" "V" "power-plug"
registerTopic "AC_out_frequency" "Hz" "current-ac"
registerTopic "PV_in_voltage" "V" "solar-panel-large"
registerTopic "PV_in_current" "A" "solar-panel-large"
registerTopic "PV_in_watts" "W" "solar-panel-large"
registerTopic "PV_in_watthour" "Wh" "solar-panel-large"
registerTopic "SCC_voltage" "V" "current-dc"
registerTopic "Load_pct" "%" "brightness-percent"
registerTopic "Load_watt" "W" "chart-bell-curve"
registerTopic "Load_watthour" "Wh" "chart-bell-curve"
registerTopic "Load_va" "VA" "chart-bell-curve"
registerTopic "Bus_voltage" "V" "details"
registerTopic "Heatsink_temperature" "°C" "details"
registerTopic "Battery_capacity" "%" "battery-outline"
registerTopic "Battery_voltage" "V" "battery-outline"
registerTopic "Battery_charge_current" "A" "current-dc"
registerTopic "Battery_discharge_current" "A" "current-dc"
registerTopic "Load_status_on" "" "power"
registerTopic "SCC_charge_on" "" "power"
registerTopic "AC_charge_on" "" "power"
registerTopic "Battery_recharge_voltage" "V" "current-dc"
registerTopic "Battery_under_voltage" "V" "current-dc"
registerTopic "Battery_bulk_voltage" "V" "current-dc"
registerTopic "Battery_float_voltage" "V" "current-dc"
registerTopic "Max_grid_charge_current" "A" "current-ac"
registerTopic "Max_charge_current" "A" "current-ac"
registerTopic "Out_source_priority" "" "grid"
registerTopic "Charger_source_priority" "" "solar-power"
registerTopic "Battery_redischarge_voltage" "V" "battery-negative"

# Add in a separate topic so we can send raw commands from assistant back to the inverter via MQTT (such as changing power modes etc)...
registerInverterRawCMD

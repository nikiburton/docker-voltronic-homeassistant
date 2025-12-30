#!/bin/bash
#
# Script para registrar sensores en Home Assistant via MQTT Discovery
# y publicar el estado inicial desde el inversor.

BIN="/usr/bin/inverter_poller"
CONF="/opt/inverter-mqtt/inverter.conf"
MQTT_CONF="/opt/inverter-mqtt/mqtt.json"

# --- Verificar existencia de archivos ---
for f in "$BIN" "$CONF" "$MQTT_CONF"; do
    [ ! -f "$f" ] && echo "ERROR: No se encuentra $f" && exit 1
done

# --- Leer configuración MQTT ---
MQTT_SERVER=$(jq -r '.server' "$MQTT_CONF")
MQTT_PORT=$(jq -r '.port' "$MQTT_CONF")
MQTT_USERNAME=$(jq -r '.username' "$MQTT_CONF")
MQTT_PASSWORD=$(jq -r '.password' "$MQTT_CONF")
MQTT_TOPIC=$(jq -r '.topic' "$MQTT_CONF")
MQTT_DEVICENAME=$(jq -r '.devicename' "$MQTT_CONF")
MQTT_CLIENTID=$(jq -r '.clientid' "$MQTT_CONF")

echo "Iniciando MQTT Discovery en $MQTT_SERVER para dispositivo $MQTT_DEVICENAME en puerto $MQTT_PORT username $MQTT_USERNAME topic $MQTT_TOPIC y cliente $MQTT_CLIENTID"

# --- Leer datos iniciales del inversor ---
DATA=$($BIN -d)
if [ -z "$DATA" ]; then
    echo "ERROR: No se pudieron leer datos del inversor"
    exit 1
fi

# --- Función para registrar sensor y publicar estado inicial ---
registerTopic () {
    local key="$1"
    local unit="$2"
    local icon="$3"

    # Topic de configuración para Home Assistant
    local state_topic="$MQTT_TOPIC/sensor/${MQTT_DEVICENAME}_${key}"
    local config_topic="$state_topic/config"

    # JSON seguro con jq
    jq -n \
       --arg name "${MQTT_DEVICENAME}_${key}" \
       --arg unit "$unit" \
       --arg state_topic "$state_topic" \
       --arg icon "$icon" \
       '{
         name: $name,
         unit_of_measurement: $unit,
         state_topic: $state_topic,
         icon: $icon
       }' | mosquitto_pub \
       -h "$MQTT_SERVER" -p "$MQTT_PORT" \
       -u "$MQTT_USERNAME" -P "$MQTT_PASSWORD" \
       -i "$MQTT_CLIENTID" \
       -t "$config_topic"

    # Publicar valor inicial
    local value
    value=$(echo "$DATA" | jq -r --arg key "$key" '.[$key]')
    [ "$value" != "null" ] && mosquitto_pub \
       -h "$MQTT_SERVER" -p "$MQTT_PORT" \
       -u "$MQTT_USERNAME" -P "$MQTT_PASSWORD" \
       -i "$MQTT_CLIENTID" \
       -t "$state_topic" \
       -m "$value"
}

# --- Registrar todos los sensores ---
registerTopic "Inverter_mode" "" "solar-power"
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

# --- Topic para enviar comandos al inversor desde Home Assistant ---
mosquitto_pub -h "$MQTT_SERVER" -p "$MQTT_PORT" \
    -u "$MQTT_USERNAME" -P "$MQTT_PASSWORD" \
    -i "$MQTT_CLIENTID" \
    -t "$MQTT_TOPIC/sensor/$MQTT_DEVICENAME/config" \
    -m "$(jq -n --arg name "$MQTT_DEVICENAME" --arg state_topic "$MQTT_TOPIC/sensor/$MQTT_DEVICENAME" '{name: $name, state_topic: $state_topic}')"

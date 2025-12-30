#!/bin/bash

# --- RUTA CORREGIDA DEL JSON ---
MQTT_JSON="/opt/inverter-mqtt/mqtt.json"

MQTT_SERVER=`cat $MQTT_JSON | jq '.server' -r`
MQTT_PORT=`cat $MQTT_JSON | jq '.port' -r`
MQTT_TOPIC=`cat $MQTT_JSON | jq '.topic' -r`
MQTT_DEVICENAME=`cat $MQTT_JSON | jq '.devicename' -r`
MQTT_USERNAME=`cat $MQTT_JSON | jq '.username' -r`
MQTT_PASSWORD=`cat $MQTT_JSON | jq '.password' -r`
MQTT_CLIENTID=`cat $MQTT_JSON | jq '.clientid' -r`

while read rawcmd;
do
    echo "Incoming request send: [$rawcmd] to inverter."
    # --- RUTA CORREGIDA DEL BINARIO ---
    /usr/bin/inverter_poller -r $rawcmd;

done < <(mosquitto_sub -h $MQTT_SERVER -p $MQTT_PORT -u "$MQTT_USERNAME" -P "$MQTT_PASSWORD" -i $MQTT_CLIENTID -t "$MQTT_TOPIC/sensor/$MQTT_DEVICENAME" -q 1)

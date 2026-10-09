#!/bin/sh

bat_path="/sys/class/power_supply/BAT1"

while true; do

    if [ -d "$bat_path" ]; then
        read -r cap < "$bat_path/capacity"
        read -r status < "$bat_path/status"

        if [ "$status" = "Charging" ]; then
            bat_icon="󰂄"
        elif [ "$cap" -le 20 ]; then
            bat_icon="󰁺"
        elif [ "$cap" -le 50 ]; then
            bat_icon="󰁽"
        elif [ "$cap" -le 80 ]; then
            bat_icon="󰂀"
        else
            bat_icon="󰁹"
        fi
        bat_str="${bat_icon} ${cap}%"
    else
        bat_str="󰂑 N/A"
    fi

    echo "$(date +' %d/%m|󱑇 %H:%M')|$bat_str|󰣇"
    sleep 5
done

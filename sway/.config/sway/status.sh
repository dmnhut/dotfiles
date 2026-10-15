#!/bin/bash
# Swaybar Status Script - Catppuccin Mocha Modern Capsule Theme

trap : USR1

# Catppuccin Mocha Color Palette
c_surf="#313244"
c_text="#cdd6f4"
c_dim="#6c7086"
c_red="#f38ba8"
c_peach="#fab387"
c_yellow="#f9e2af"
c_green="#a6e3a1"
c_blue="#89b4fa"
c_mauve="#cba6f7"
c_lavender="#b4befe"
c_cyan="#89dceb"

pill() {
    local icon_color="$1"
    local icon="$2"
    local text="$3"
    printf '<span foreground="%s"></span><span background="%s" foreground="%s">%s</span><span background="%s" foreground="%s"> %s</span><span foreground="%s"></span> ' \
        "$c_surf" "$c_surf" "$icon_color" "$icon" "$c_surf" "$c_text" "$text" "$c_surf"
}

icon_only_pill() {
    local icon_color="$1"
    local icon="$2"
    printf '<span foreground="%s"></span><span background="%s" foreground="%s">%s</span><span foreground="%s"></span>' \
        "$c_surf" "$c_surf" "$icon_color" "$icon" "$c_surf"
}

while true; do
    # 1. Screen recording indicator (wf-recorder)
    rec_str=""
    if pgrep -x "wf-recorder" > /dev/null 2>&1; then
        rec_str=$(printf '<span foreground="%s"></span><span background="%s" foreground="#11111b"><b>󰑋 REC</b></span><span foreground="%s"></span> ' "$c_red" "$c_red" "$c_red")
    fi

    # 2. Network (WiFi / Ethernet)
    net_str=""
    if [ -d /sys/class/net/eth0 ] && [ "$(cat /sys/class/net/eth0/operstate 2>/dev/null)" = "up" ]; then
        net_str=$(pill "$c_green" "󰈀 " "Ethernet")
    elif [ -d /sys/class/net/usb0 ] && [ "$(cat /sys/class/net/usb0/operstate 2>/dev/null)" = "up" ]; then
        net_str=$(pill "$c_green" "󰈀 " "USB Tether")
    else
        ssid=$(iwctl station wlan0 show 2>/dev/null | awk -F'   +' '/Connected network/ {print $3}')
        if [ -n "$ssid" ]; then
            net_str=$(pill "$c_blue" "󰖩 " "WiFi")
        else
            net_str=$(pill "$c_dim" "󰤮 " "Offline")
        fi
    fi

    # 3. Volume (wpctl)
    vol_str=""
    wp_out=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)
    if [ -n "$wp_out" ]; then
        read -r _ vol muted <<< "$wp_out"
        vol_val=$(awk -v v="$vol" 'BEGIN { printf "%d", v * 100 }')
        if [ -n "$muted" ]; then
            vol_str=$(pill "$c_dim" "󰝟 " "Mute")
        elif [ "$vol_val" -eq 0 ]; then
            vol_str=$(pill "$c_dim" "󰝟 " "0%")
        elif [ "$vol_val" -le 30 ]; then
            vol_str=$(pill "$c_peach" "󰕿 " "${vol_val}%")
        elif [ "$vol_val" -le 70 ]; then
            vol_str=$(pill "$c_peach" "󰖀 " "${vol_val}%")
        else
            vol_str=$(pill "$c_peach" "󰕾 " "${vol_val}%")
        fi
    fi

    # 4. Brightness (sysfs)
    bri_str=""
    bl_dir=$(ls -d /sys/class/backlight/* 2>/dev/null | head -n 1 || true)
    if [ -n "$bl_dir" ] && [ -f "$bl_dir/brightness" ]; then
        read -r cur_b < "$bl_dir/brightness"
        read -r max_b < "$bl_dir/max_brightness"
        if [ "$max_b" -gt 0 ]; then
            bri_val=$(( cur_b * 100 / max_b ))
            if [ "$bri_val" -le 33 ]; then
                bri_icon="󰃞 "
            elif [ "$bri_val" -le 66 ]; then
                bri_icon="󰃟 "
            else
                bri_icon="󰃠 "
            fi
            bri_str=$(pill "$c_yellow" "$bri_icon" "${bri_val}%")
        fi
    fi

    # 5. RAM Usage
    ram_val=$(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {if (t>0) printf "%d", (t-a)*100/t}' /proc/meminfo 2>/dev/null || true)
    if [ -n "$ram_val" ]; then
        if [ "$ram_val" -ge 85 ]; then
            ram_color="$c_red"
        elif [ "$ram_val" -ge 65 ]; then
            ram_color="$c_peach"
        else
            ram_color="$c_mauve"
        fi
        ram_str=$(pill "$ram_color" "󰘚 " "${ram_val}%")
    else
        ram_str=""
    fi

    # 6. Battery
    bat_str=""
    bat_path=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n 1 || true)
    if [ -n "$bat_path" ] && [ -f "$bat_path/capacity" ]; then
        read -r cap < "$bat_path/capacity"
        read -r status < "$bat_path/status"

        if [ "$status" = "Charging" ]; then
            bat_icon="󰂄"
            bat_color="$c_green"
        elif [ "$status" = "Full" ]; then
            bat_icon="󰁹"
            bat_color="$c_green"
        elif [ "$cap" -le 10 ]; then
            bat_icon="󰂃"
            bat_color="$c_red"
        elif [ "$cap" -le 20 ]; then
            bat_icon="󰁺"
            bat_color="$c_peach"
        elif [ "$cap" -le 40 ]; then
            bat_icon="󰁼"
            bat_color="$c_yellow"
        elif [ "$cap" -le 60 ]; then
            bat_icon="󰁾"
            bat_color="$c_green"
        elif [ "$cap" -le 80 ]; then
            bat_icon="󰂀"
            bat_color="$c_green"
        else
            bat_icon="󰁹"
            bat_color="$c_green"
        fi
        bat_str=$(pill "$bat_color" "$bat_icon" "${cap}%")
    fi

    # 7. Date & Time
    date_part=$(date +'%a %d/%m')
    time_part=$(date +'%H:%M')
    datetime_str=$(pill "$c_lavender" "󰃭 " "${date_part} <span foreground=\"$c_cyan\">󱑆 </span> ${time_part}")

    # 8. Arch Logo badge
    arch_str=$(icon_only_pill "$c_cyan" "󰣇 ")

    echo "${rec_str}${net_str}${vol_str}${bri_str}${ram_str}${bat_str}${datetime_str}${arch_str}"
    sleep 2 &
    wait $!
done

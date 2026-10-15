#!/bin/bash

# If wf-recorder is already running, stop recording cleanly
if pgrep -x "wf-recorder" > /dev/null 2>&1; then
    pkill -SIGINT -x wf-recorder
    exit 0
fi

OUTPUT_DIR="$HOME/Videos"
mkdir -p "$OUTPUT_DIR"
FILENAME="$OUTPUT_DIR/recording_$(date +'%Y-%m-%d_%H-%M-%S').mp4"

MODE="${1:-area}"

case "$MODE" in
    screen)
        exec wf-recorder -f "$FILENAME"
        ;;
    screen-audio)
        exec wf-recorder --audio -f "$FILENAME"
        ;;
    audio)
        GEOM=$(slurp) || exit 0
        [ -z "$GEOM" ] && exit 0
        exec wf-recorder -a="$(pactl get-default-sink).monitor" -g "$GEOM" -f "$FILENAME"
        ;;
    area|*)
        GEOM=$(slurp) || exit 0
        [ -z "$GEOM" ] && exit 0
        exec wf-recorder -g "$GEOM" -f "$FILENAME"
        ;;
esac

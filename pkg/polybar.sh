#!/bin/bash

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.25; done

# Launch Polybar, using default config location ~/.config/polybar/config
if [[ -e /home/$USER/.firstBoot ]]; then
    exit
else
    if [[ ! -f /home/$USER/.config/monocleOS/launcher.conf ]]; then statusbar=compact
    else source /home/$USER/.config/monocleOS/launcher.conf; fi
    polybar $statusbar &
    echo "Polybar ($statusbar) launched..."
fi

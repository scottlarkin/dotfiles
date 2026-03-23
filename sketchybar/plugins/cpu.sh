#!/bin/sh

CPU_USAGE=$(ps -A -o %cpu | awk '{s+=$1} END {print s}')
LOGICAL_CPUS=$(sysctl -n hw.logicalcpu)
CPU_PERCENT=$(echo "$CPU_USAGE $LOGICAL_CPUS" | awk '{printf "%.0f", $1 / $2}')

ICON="󰻠"
COLOR=0xff9ece6a

if [ "$CPU_PERCENT" -gt 80 ]; then
  COLOR=0xfff7768e
fi

sketchybar --set "$NAME" icon="$ICON" label="${CPU_PERCENT}%" icon.color="$COLOR" label.color="$COLOR" background.color=0xff414868

#!/bin/sh

PAGE_SIZE=$(sysctl -n hw.pagesize)
MEM_TOTAL=$(sysctl -n hw.memsize)
MEM_TOTAL_GB=$(echo "$MEM_TOTAL" | awk '{printf "%.0f", $1 / 1073741824}')

# Parse vm_stat for active + wired + compressed pages
STATS=$(vm_stat)
ACTIVE=$(echo "$STATS" | awk '/Pages active/ {gsub(/\./,"",$3); print $3}')
WIRED=$(echo "$STATS" | awk '/Pages wired/ {gsub(/\./,"",$4); print $4}')
COMPRESSED=$(echo "$STATS" | awk '/Pages occupied by compressor/ {gsub(/\./,"",$5); print $5}')

MEM_USED_GB=$(echo "$ACTIVE $WIRED $COMPRESSED $PAGE_SIZE" | awk '{printf "%.1f", ($1 + $2 + $3) * $4 / 1073741824}')
MEM_PERCENT=$(echo "$MEM_USED_GB $MEM_TOTAL_GB" | awk '{printf "%.0f", ($1 / $2) * 100}')

ICON="󰍛"
COLOR=0xff7dcfff

if [ "$MEM_PERCENT" -gt 85 ]; then
  COLOR=0xfff7768e
elif [ "$MEM_PERCENT" -gt 65 ]; then
  COLOR=0xffe0af68
fi

sketchybar --set "$NAME" icon="$ICON" label="${MEM_USED_GB}/${MEM_TOTAL_GB}G" icon.color="$COLOR" label.color="$COLOR" background.color=0xff414868

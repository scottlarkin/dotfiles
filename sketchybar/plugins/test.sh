#!/bin/sh

FOCUSED=$(aerospace list-workspaces --focused | head -n1)

if [ "$1" = "$FOCUSED" ]; then
  sketchybar --set "$NAME" label.color="0xff7aa2f7" background.color="0xff414868" background.border_color="0xff7aa2f7" background.border_width=1
else
  sketchybar --set "$NAME" label.color="0xff565f89" background.color="0xff24283b" background.border_width=0
fi

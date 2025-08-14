#!/bin/sh

if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
  sketchybar --set $NAME label.color="0xff2ce5e7"

else
  sketchybar --set $NAME label.color="0xffffffff"
fi

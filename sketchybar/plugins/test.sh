#!/bin/sh

if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
  sketchybar --set $NAME label.color="0xffdf6309"

else
  sketchybar --set $NAME label.color="0xffffffff"
fi

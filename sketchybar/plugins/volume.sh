#!/bin/sh

# The volume_change event supplies a $INFO variable in which the current volume
# percentage is passed to the script.

if [ "$SENDER" = "volume_change" ]; then
  VOLUME="$INFO"
else
  # Get initial volume state
  VOLUME=$(osascript -e "output volume of (get volume settings)")
fi

case "$VOLUME" in
[6-9][0-9] | 100)
  ICON="󰕾"
  ;;
[3-5][0-9])
  ICON="󰖀"
  ;;
[1-9] | [1-2][0-9])
  ICON="󰕿"
  ;;
*) ICON="󰖁" ;;
esac

# Set colors based on volume level
COLOR=0xff7aa2f7
BG_COLOR=0xff414868

case "$VOLUME" in
[6-9][0-9] | 100)
  COLOR=0xff7aa2f7
  ;;
[3-5][0-9])
  COLOR=0xffe0af68
  ;;
[1-9] | [1-2][0-9])
  COLOR=0xfff7768e
  ;;
*)
  COLOR=0xfff7768e
  ;;
esac

sketchybar --set "$NAME" icon="$ICON" label="$VOLUME%" icon.color="$COLOR" label.color="$COLOR" background.color="$BG_COLOR" icon.padding_left=2 icon.padding_right=2

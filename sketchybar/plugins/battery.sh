#!/bin/sh

PERCENTAGE="$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)"
CHARGING="$(pmset -g batt | grep 'AC Power')"

if [ "$PERCENTAGE" = "" ]; then
  exit 0
fi

case "${PERCENTAGE}" in
  9[0-9]|100) ICON=""
  ;;
  [6-8][0-9]) ICON=""
  ;;
  [3-5][0-9]) ICON=""
  ;;
  [1-2][0-9]) ICON=""
  ;;
  *) ICON=""
esac

if [[ "$CHARGING" != "" ]]; then
  ICON=""
fi

# The item invoking this script (name $NAME) will get its icon and label
# updated with the current battery status

# Set colors based on battery level
COLOR=0xff9ece6a
BG_COLOR=0xff414868

case "${PERCENTAGE}" in
  9[0-9]|100) COLOR=0xff9ece6a ;;
  [6-8][0-9]) COLOR=0xffe0af68 ;;
  [3-5][0-9]) COLOR=0xffe0af68 ;;
  [1-2][0-9]) COLOR=0xfff7768e ;;
  *) COLOR=0xfff7768e ;;
esac

if [ -n "$CHARGING" ]; then
  COLOR=0xff7dcfff
fi

sketchybar --set "$NAME" icon="$ICON" label="${PERCENTAGE}%" icon.color="$COLOR" label.color="$COLOR" background.color="$BG_COLOR" icon.padding_left=2 icon.padding_right=2

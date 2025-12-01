#!/bin/sh

# Some events send additional information specific to the event in the $INFO
# variable. E.g. the front_app_switched event sends the name of the newly
# focused application in the $INFO variable:
# https://felixkratz.github.io/SketchyBar/config/events#events-and-scripting

if [ "$SENDER" = "front_app_switched" ]; then
  APP_NAME="$INFO"
  # Truncate long app names to keep the bar clean
  if [ ${#APP_NAME} -gt 20 ]; then
    APP_NAME="${APP_NAME:0:17}..."
  fi
  sketchybar --set "$NAME" label="$APP_NAME"
fi

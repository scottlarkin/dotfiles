#!/bin/sh

DISK_USAGE=$(df -k /System/Volumes/Data | awk 'NR == 2 {print $5}')

sketchybar --set "$NAME" label="$DISK_USAGE"

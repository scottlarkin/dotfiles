#!/bin/sh
# muninn (dockerised memory system) health indicator.
# Reads the server's own /v1/health deps map from the loopback API — neo4j
# store/recall, ollama embeds, and the LLM probe when enabled — and shows a
# brain icon whose colour + trailing status glyph reflect reachability:
#   all deps up            -> green  brain + check
#   some up, some down      -> yellow brain + warning + <deps> (which are down)
#   all down / unreachable  -> red    brain + cross
# Uses the endpoint (the actual memory chain), not raw ports, so a stray legacy
# instance can't lie.

ICON="󰧑" # nf-md-brain (U+F09D1)

# Status glyphs built via printf octal escapes so they survive edits regardless
# of editor/PUA handling: nf-fa-check (U+F00C), nf-fa-times (U+F00D),
# nf-fa-warning (U+F071).
CHECK=$(printf '\357\200\214')
CROSS=$(printf '\357\200\215')
WARN=$(printf '\357\201\261')

GREEN=0xff9ece6a
YELLOW=0xffe0af68
RED=0xfff7768e
BG=0xff414868

health=$(curl -s --connect-timeout 0.3 --max-time 0.6 http://127.0.0.1:47688/v1/health)
deps=$(echo "$health" | jq -c '.deps // {}' 2>/dev/null)
total=$(echo "$deps" | jq 'length' 2>/dev/null || echo 0)

if [ -z "$deps" ] || [ "$total" = 0 ]; then
  COLOR=$RED
  LABEL="$CROSS" # server unreachable / no deps reported
else
  up=$(echo "$deps" | jq '[.[] | select(. == true)] | length' 2>/dev/null || echo 0)
  down=$(echo "$deps" | jq -r 'to_entries | map(select(.value != true)) | .[].key' 2>/dev/null | paste -sd, -)
  if [ "$up" = "$total" ]; then
    COLOR=$GREEN
    LABEL="$CHECK" # all good
  elif [ "$up" = 0 ]; then
    COLOR=$RED
    LABEL="$CROSS" # fully down
  else
    COLOR=$YELLOW
    LABEL="$WARN $down" # which deps are down
  fi
fi

sketchybar --set "$NAME" icon="$ICON" label="$LABEL" icon.color="$COLOR" label.color="$COLOR" background.color="$BG"

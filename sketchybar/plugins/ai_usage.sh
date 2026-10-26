#!/bin/sh
# ai-usage lives in ~/.local/bin; sketchybar's PATH has neither it nor homebrew python.

PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"

# Glyphs via printf octal escapes (see AGENTS.md): nf-md-creation (U+F0674) for Claude,
# nf-md-code_braces (U+F0169) for Codex, nf-fa-times (U+F00D) on error.
case "$1" in
  claude) ICON=$(printf '\363\260\231\264') ;;
  codex) ICON=$(printf '\363\260\205\251') ;;
esac
CROSS=$(printf '\357\200\215')

GREEN=0xff9ece6a
YELLOW=0xffe0af68
RED=0xfff7768e

left=$(ai-usage --json "$1" 2>/dev/null |
  jq -r --arg p "$1" '.[$p].windows // empty | map(100 - .used) | min // empty | floor' 2>/dev/null)

if [ -z "$left" ]; then
  COLOR=$RED
  LABEL="$CROSS"
elif [ "$left" -ge 50 ]; then
  COLOR=$GREEN
  LABEL="$left%"
elif [ "$left" -ge 20 ]; then
  COLOR=$YELLOW
  LABEL="$left%"
else
  COLOR=$RED
  LABEL="$left%"
fi

sketchybar --set "$NAME" icon="$ICON" label="$LABEL" icon.color="$COLOR" label.color="$COLOR"

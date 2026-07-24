# sketchybar/AGENTS.md

SketchyBar menu bar config. Symlinked as `~/.config/sketchybar`. See the repo-root
[`AGENTS.md`](../AGENTS.md) for commit and symlink rules.

```
sketchybarrc      the whole bar: defaults, then one --add/--set per item (mode 755, NO shebang)
plugins/*.sh      one script per item; POSIX sh, executable, invoked by sketchybar with env vars
```

## The item ↔ plugin contract

`sketchybarrc` sets `PLUGIN_DIR="$CONFIG_DIR/plugins"` and every item points at a script:

```sh
sketchybar --add item cpu right \
           --set cpu update_freq=5 icon=󰻠 script="$PLUGIN_DIR/cpu.sh" \
           --subscribe cpu <event>
```

SketchyBar runs the script with these variables — a plugin reads them, computes, and writes back
with a single `sketchybar --set "$NAME" ...`. It never reads state; it is a pure render pass.

| Var        | Meaning                                                                |
| ---------- | ---------------------------------------------------------------------- |
| `$NAME`    | The item to `--set`. **Always quote it and always use it** — never hardcode the item name |
| `$SENDER`  | Which subscribed event fired (`front_app.sh` branches on this)          |
| `$INFO`    | Event payload, e.g. the new app name for `front_app_switched`           |
| `$SELECTED`| For space items: whether this space is focused                          |

Two update models, pick one per item: `update_freq=<seconds>` for polling (clock 1s, cpu/ram 5s,
muninn 15s, battery 120s) or `--subscribe <item> <event>` for push (`volume_change`,
`front_app_switched`, `system_woke`, `power_source_change`). Add `updates=when_shown` to items that
are pointless off-screen (volume does this). Don't poll something an event already reports.

## Adding an item

1. Write `plugins/<name>.sh`: `#!/bin/sh`, `chmod +x`, 2-space indent, one terminating
   `sketchybar --set "$NAME" ...`.
2. Append an `--add item <name> <left|right> --set <name> ...` block in `sketchybarrc`, copying the
   standard pill block verbatim so it matches its neighbours:
   ```
   background.color=0xff414868   background.corner_radius=7   background.height=20
   background.drawing=on         padding_left=3               padding_right=7
   label.padding_left=0          label.padding_right=8
   ```
   Right-side items are chained into one long `\`-continued invocation — extend the chain, don't
   start a second `sketchybar` call.
3. Reload and check it renders (below).

**Colours are inline hex literals, repeated everywhere — there is no palette variable.** Tokyo Night:

```
bar bg   0x801a1b26   item bg  0xff24283b / 0xff414868
green    0xff9ece6a   blue     0xff7aa2f7   cyan   0xff7dcfff
purple   0xffbb9af7   yellow   0xffe0af68   red    0xfff7768e   dim  0xff565f89
```

Use an existing literal rather than inventing a shade. Extracting them into shell variables would be
a reasonable refactor but touches every line of `sketchybarrc` — ask before doing it.

Fonts: `Hack Nerd Font:Bold:16.0` for icons, `:13.0` for labels, set once via `sketchybar --default`.

## Glyphs

Most plugins paste Nerd Font glyphs literally (`󰻠`, `󰍛`, `󰥔`, `󰧑`). `muninn.sh` instead builds its
status glyphs with printf octal escapes — `CHECK=$(printf '\357\200\214')` — deliberately, so they
survive editors that mangle Private Use Area codepoints. If a literal glyph ever renders as a box,
that's the escape hatch; prefer it for anything in the U+F0xx range.

## Workspaces (the AeroSpace coupling)

Space items are **generated at load time**, not declared:

```sh
workspaces=$(aerospace list-workspaces --monitor all --empty no)
sketchybar --add event aerospace_workspace_change
for sid in $workspaces; do
  sketchybar --add item space.$sid left \
    --subscribe space.$sid aerospace_workspace_change \
    --set space.$sid label="$sid" click_script="aerospace workspace $sid" \
                     script="$PLUGIN_DIR/test.sh $sid"
done
```

Consequences to keep in mind:

- **Empty workspaces get no item** (`--empty no`), so the bar changes shape as you open windows. The
  bar only re-enumerates on reload.
- `aerospace_workspace_change` is a **custom event**, fired by `.aerospace.toml`'s
  `exec-on-workspace-change`. If workspace highlighting stops updating, suspect that hook, not this
  directory.
- **`plugins/test.sh` is the workspace highlighter, not a test.** It compares `$1` against
  `aerospace list-workspaces --focused` and sets border/label colours. The name is misleading;
  renaming it means updating both the `script=` and the initial-trigger loop.
- **`plugins/space.sh` is dead code** — referenced nowhere. It's the stock SketchyBar mission-control
  space handler, obsolete since AeroSpace took over. Delete it if you're cleaning up.
- The initial-trigger loop hardcodes `/Users/scottlarkin/repos/dotfiles/sketchybar/plugins/test.sh`
  instead of `$PLUGIN_DIR/test.sh`. Fix that if you're already in the block.

## External dependencies

Plugins shell out to: `pmset` (battery), `sysctl` / `vm_stat` / `ps` / `awk` (cpu, ram), `osascript`
(volume), `date` (clock), `aerospace` (spaces), and `curl` + `jq` (muninn). `jq` is the newest
addition — a plugin that needs a non-stock binary should degrade to a visible error state rather than
render blank, the way `muninn.sh` shows a red cross on an unreachable endpoint.

`muninn.sh` polls `http://127.0.0.1:47688/v1/health` with a hard 0.6s cap
(`--connect-timeout 0.3 --max-time 0.6`). **Keep timeouts well under `update_freq`** — a plugin that
blocks stalls the bar.

## Verification

```sh
sh -n sketchybar/plugins/<name>.sh          # syntax only, no execution
NAME=cpu sh sketchybar/plugins/cpu.sh       # run one plugin against the live bar
sketchybar --reload                         # reload the whole config
```

Set the env the plugin actually reads when testing by hand: `NAME=front_app
SENDER=front_app_switched INFO=Ghostty sh plugins/front_app.sh`. A plugin that produces no output and
no error is a pass only if the bar visibly changed — check the bar, not just the exit code.

`sketchybarrc` has no shebang and is sourced by sketchybar, so **don't run it directly**; use
`--reload`. `shellcheck` is not installed; `brew install shellcheck` then
`shellcheck -s sh plugins/*.sh` if a change is large enough to warrant it.

If the bar disappears entirely after a reload, the config errored partway through — check
`sketchybar` in Console.app or run `sketchybar --reload` from a terminal and read stderr.

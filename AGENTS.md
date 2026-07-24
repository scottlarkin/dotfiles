# AGENTS.md

Personal macOS dotfiles for a single machine. **Configs are consumed live through symlinks** — there
is no build, no install step, and no test suite. Editing a file here changes the running system as
soon as the relevant tool reloads. Verify by reloading, not by running tests.

Scoped guidance exists for the two non-trivial areas: [`nvim/AGENTS.md`](nvim/AGENTS.md),
[`sketchybar/AGENTS.md`](sketchybar/AGENTS.md).

## Layout

| Path              | Configures                       | Language        | Linked as              |
| ----------------- | -------------------------------- | --------------- | ---------------------- |
| `nvim/`           | Neovim (LazyVim + lazy.nvim)     | Lua             | `~/.config/nvim`       |
| `sketchybar/`     | SketchyBar menu bar              | sh (POSIX)      | `~/.config/sketchybar` |
| `.aerospace.toml` | AeroSpace tiling WM              | TOML            | `~/.aerospace.toml`    |
| `.tmux.conf`      | tmux                             | tmux config     | `~/.tmux.conf`         |
| `.tmux/`          | tpm + cloned tmux plugins        | (vendored)      | `~/.tmux`              |
| `tmux/`           | catppuccin theme clone           | (vendored)      | `~/.config/tmux`       |
| `.zshrc`          | zsh (oh-my-zsh + starship)       | zsh             | `~/.zshrc`             |
| `ghostty/config`  | Ghostty terminal                 | key = value     | `~/.config/ghostty`    |
| `atuin/`          | atuin shell history              | TOML            | **dead link** (below)  |

`aerospace` → `sketchybar` is the one real cross-file dependency. `.aerospace.toml` launches both
`sketchybar` and `borders` (JankyBorders) via `after-startup-command`, and fires
`sketchybar --trigger aerospace_workspace_change` from `exec-on-workspace-change`. Workspace pills in
the bar only update because of that hook — change one side and check the other. The coupling is also
numeric: `sketchybar --bar height=34` must stay in sync with AeroSpace's
`[gaps] outer.top = [{ monitor."^built-in retina display$" = 8 }, 34]`, or windows sit under the bar
on external monitors. Border colours are re-set inline on every `[mode.service.binding]` line, so
changing the active colour means changing it in several places.

Everything here is **macOS-only and single-machine**: no `uname`/hostname branching, no `*.local`
include hooks, hardcoded `/opt/homebrew` and `/Users/scottlarkin` paths. Don't add portability
scaffolding unasked.

Colour scheme is Tokyo Night everywhere (nvim `tokyonight-night`, ghostty `TokyoNight Night`,
sketchybar `0xff24283b` / `0xff414868` / `0xff7aa2f7` literals). tmux is the odd one out (dracula).

## Symlink model

Every link was created by hand; there is no stow / chezmoi / `install.sh`. Directories are linked
whole, so **new files inside a linked directory are picked up with no action needed**:

```
~/.zshrc          -> ~/repos/dotfiles/.zshrc
~/.tmux.conf      -> ~/repos/dotfiles/.tmux.conf
~/.aerospace.toml -> ~/repos/dotfiles/.aerospace.toml
~/.tmux           -> ~/repos/dotfiles/.tmux
~/.config/nvim    -> ~/repos/dotfiles/nvim
~/.config/tmux    -> ~/repos/dotfiles/tmux
~/.config/sketchybar -> ~/repos/dotfiles/sketchybar
~/.config/ghostty -> ~/repos/dotfiles/ghostty
~/.config/atuin/atuin -> ~/repos/dotfiles/atuin   # nested one level too deep; atuin never reads it
```

Adding a new tool means creating the link explicitly (`ln -s ~/repos/dotfiles/<x> ~/.config/<x>`)
and saying so — don't assume a new top-level directory is active.

## Conventions

- **Match the file you're in.** No formatter is configured (`stylua`, `shfmt`, `shellcheck` are all
  absent from PATH) and there is no `.editorconfig`. Lua is tab-indented, ~120 col; shell is
  2-space, POSIX `sh`; TOML/tmux configs use `# ===` banner comments to group sections.
- **Comments explain non-obvious *why*.** `nvim/lua/plugins/muninn.lua` and
  `sketchybar/plugins/muninn.sh` are the reference standard: they document why a debounce exceeds a
  throttle interval, why glyphs use octal escapes. Upstream-boilerplate comments (the SketchyBar
  demo preamble, LazyVim's `lazy.lua` notes) can be left alone or deleted, not paraphrased.
- **Prefer deleting commented-out blocks** over adding more. `copilot.lua` and `tabby.lua` are
  entirely dead commented code; if you touch them, remove the corpse rather than editing around it.
- **No absolute `/Users/scottlarkin` paths in new code** — use `$CONFIG_DIR`, `$HOME`, `~`, or
  `vim.fn.stdpath()`. Two existing violations are noted under Gotchas.
- **No secrets, ever.** Nothing here is encrypted or gitignored; this repo is plain text. API keys,
  tokens, and session values belong in the environment, not in a tracked file. `minuet.lua` shows
  the pattern for a required-but-meaningless key (`api_key = "TERM"` for a local Ollama endpoint).

## Verification

There are no tests. The feedback loop is reload-and-look. After editing, run the matching command
and report what it printed:

| Changed          | Check                                                                    |
| ---------------- | ------------------------------------------------------------------------ |
| `.zshrc`         | `zsh -n .zshrc` (syntax), then `exec zsh`. Startup cost: `time zsh -i -c exit` |
| `nvim/`          | `nvim --headless "+Lazy! sync" +qa` then `nvim --headless "+checkhealth" +qa` — see `nvim/AGENTS.md` |
| `sketchybar/`    | `sketchybar --reload`; run the single plugin directly — see `sketchybar/AGENTS.md` |
| `.aerospace.toml`| `aerospace reload-config` (errors surface as a macOS notification; a bad config is rejected, not partially applied) |
| `.tmux.conf`     | `tmux source-file ~/.tmux.conf` from inside a session; errors print to the status line |
| `ghostty/config` | Reload in-app (`cmd+shift+,`). The `ghostty` CLI is not on PATH on this machine, so `ghostty +validate-config` won't run |
| `atuin/`         | `atuin doctor` — but read the drift warning below first |

Optional linters, if worth installing for a larger change:
`brew install stylua shellcheck shfmt`, then `stylua --check nvim/` and
`shellcheck -s sh sketchybar/plugins/*.sh`. Do not add a config file for these without asking —
introducing `.stylua.toml` would rewrite all 18 Lua files in `nvim/` in one diff.

## Commits

- History is 18 commits, all authored `scottravio <scott@ravio.com>` — the global git config
  default, so no `--author` override is needed. **Never add a `Co-Authored-By:` trailer.**
- Subjects are terse lowercase fragments, no conventional-commit prefixes: `update dots`,
  `update tmux`, `update bar`, `update nvim`, `mouse on`, `alias`. Match that. Body only when the
  *why* isn't obvious from the diff.
- Default branch is `master`. Commit directly to it; this repo has no PR flow and no CI.
- Commit `nvim/lazy-lock.json` alongside any plugin change — it's tracked and is the only pinning
  mechanism here.
- Do **not** commit `.tmux/plugins/*` or `tmux/plugins/*`. Those are tpm-cloned upstream repos with
  their own `.git` directories.

## Gotchas / current state

- **`atuin/` is linked to the wrong depth and is therefore dead.** The link is
  `~/.config/atuin/atuin -> repo/atuin`, one level too deep; atuin reads `~/.config/atuin/config.toml`,
  which is a *real* 10KB file that differs from this repo's copy. Editing `atuin/config.toml` here
  changes nothing. Fixing it means replacing the real file with a link and reconciling the two
  versions — ask first. `atuin-receipt.json` is a cargo-dist installer artifact, not config; it was
  committed by accident.
- **`term/` and `site/` are empty leftovers.** Every directory under them is empty (`term/src`,
  `term/dist`, `term/node_modules`), which is why git doesn't report them as untracked. They are not
  part of any config; ignore them, or delete them if asked.
- **Tracked vs. working tree drifts.** 34 files are tracked but several live additions are not yet
  committed (`nvim/lua/plugins/minuet.lua`, `nvim/lua/plugins/muninn.lua`,
  `sketchybar/plugins/muninn.sh`). Check `git status` before assuming the committed state matches
  what's running.
- **No `.gitignore`** and `.git/info/exclude` is untouched. The only thing filtering anything is the
  user's global ignore (`~/.config/git/ignore`), which covers `**/.claude/settings.local.json`.
  Untracked noise otherwise has to be avoided by hand — `.tmux/` alone is 965 files.
- **Hardcoded absolute path in `sketchybar/sketchybarrc`**: the initial workspace-trigger loop calls
  `/Users/scottlarkin/repos/dotfiles/sketchybar/plugins/test.sh` while every other reference uses
  `$PLUGIN_DIR`. Fix it to `$PLUGIN_DIR/test.sh` if you're already editing that block.
- **`.zshrc` is machine-pinned**: literal `/Users/scottlarkin/Library/pnpm`, a `pnpm@9` Homebrew
  path, and an Aikido-managed block between `# aikido-endpoint-*-start` / `-end` markers. **Do not
  edit inside the Aikido markers** — that block is rewritten by the endpoint agent and your changes
  will be lost.
- `.zshrc` sets `bindkey -v` (vi mode) and defines `commit`/`typos`/`typosfix` aliases that shell
  out to `cursor-agent`. Renaming or shadowing those aliases will break muscle memory.

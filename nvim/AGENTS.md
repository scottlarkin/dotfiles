# nvim/AGENTS.md

LazyVim distribution on top of lazy.nvim. Symlinked as `~/.config/nvim`, so edits are live on the
next `nvim` launch. See the repo-root [`AGENTS.md`](../AGENTS.md) for commit and symlink rules.

## Layout

```
init.lua              require("config.lazy") + all raw keymaps + colorscheme + one autocmd
lua/config/lazy.lua   lazy.nvim bootstrap and setup opts (near-stock LazyVim template)
lua/plugins/*.lua     one file per concern, each returns a lazy.nvim spec
lazyvim.json          which LazyVim "extras" are enabled — machine-written by :LazyExtras
lazy-lock.json        67 plugin commit pins — machine-written by lazy.nvim; tracked, never hand-edit
snippets/             VSCode-format LuaSnip snippets (package.json + ts.json + tsx.json)
```

There is **no `lua/config/keymaps.lua`, `options.lua`, or `autocmds.lua`** — the usual LazyVim
split. Everything that would live in those files is inlined in `init.lua`. Keep it that way unless
`init.lua` gets long enough to justify splitting; don't create a half-migration.

Non-obvious global keymaps in `init.lua`, all via a `local map = vim.keymap.set` alias:
`jk`→`<esc>` (insert), `<esc>`→exit terminal mode, **`<BS>`/`<Del>` are jumplist back/forward**
(`<C-o>`/`<C-i>`), `-`→`:Oil`, `<leader>h`→LSP hover, `<C-u>`/`<C-d>` recentre with `zz`. The
colorscheme goes through a *global* `SetTheme(color)` function (default `tokyonight-night`) so it can
be called from the cmdline — it's global on purpose, not a stray `local` omission.

## Adding or changing a plugin

1. New concern → new file `lua/plugins/<name>.lua` returning a table. No registration step:
   `lua/config/lazy.lua` does `{ import = "plugins" }`, which picks up every file in the directory.
2. Overriding a LazyVim-provided plugin → set `opts` on the same repo name and LazyVim deep-merges
   (`lsp.lua`, `noice.lua` do this). For list-valued opts use the `function(_, opts)` form so you
   append instead of replacing.
3. Extending an *optional* plugin the extras may not have loaded → add `optional = true` so the spec
   is a no-op when the plugin is absent (`muninn.lua` does this for `snacks.nvim`).
4. Enabling a whole language/feature bundle → `:LazyExtras`, not a new spec file. That writes
   `lazyvim.json`. 27 extras are on, including `lang.typescript`, `lang.go`, `lang.elixir`,
   `editor.snacks_picker`, `formatting.prettier`, `test.core`, `dap.core`.

Spec conventions in this tree:

- Files return a list-of-specs table (`return { { "owner/repo", ... } }`) even for a single plugin.
  `noice.lua` and `minuet.lua` return a bare spec — both forms are valid to lazy.nvim; prefer the
  wrapped list for new files.
- `lua/config/lazy.lua` sets `defaults.lazy = false`, so **your plugins load at startup by default**.
  If a plugin is expensive, lazy-load it explicitly with `keys` / `event` / `cmd`.
- `version = false` globally — plugins track latest git commit, pinned only by `lazy-lock.json`.
- Prefer declarative `opts = {}` over `config = function()`. Use `config` only when setup needs real
  logic (`dap.lua` builds adapter paths from `mason-registry`; `blink-cmp.lua` registers snippets).
- Keymaps that belong to a plugin go in that plugin's `keys` table with a `desc`. Global,
  plugin-independent keymaps go in `init.lua` via the local `map` alias. Don't split one plugin's
  bindings across both.
- `-- stylua: ignore` above a `keys` table keeps one-line bindings from being exploded — see
  `muninn.lua` and `dap.lua`.
- **Pin with a comment explaining why.** `test.lua` holds neotest at
  `commit = "52fca6717ef972113ddd6ca223e30ad0abb2800c"` — "neotest author broke somehting in a recent
  update, this is the last stable commit". Don't silently unpin it; if you unpin, verify tests run.
- `lua/config/lazy.lua` is otherwise stock LazyVim. The one local deviation is `"tohtml"` commented
  back *into* the runtime (removed from `performance.rtp.disabled_plugins`). Keep local edits to that
  file minimal and obvious so upstream template drift stays reviewable.

## Local integrations

- **`muninn.lua`** — a custom `snacks.picker` source (`<leader>fm`) shelling out to the `muninn` CLI
  for semantic file search. The most subtle file here: it hand-rolls a debounce inside the finder
  because snacks throttles input but never debounces, and `DEBOUNCE_MS` (250) **must stay above**
  snacks' hardcoded 200ms throttle. Read its header comment fully before changing anything; the
  constants are load-bearing. Requires `muninn index` to have been run in the repo, and resolves the
  binary via `vim.fn.exepath` with a `~/go/bin/muninn` fallback (GUI nvim doesn't inherit shell PATH).
- **`minuet.lua`** — inline AI completion against **local Ollama** (`localhost:11434`,
  `qwen2.5-coder:7b`). `api_key = "TERM"` is a placeholder env var name, not a secret. `context_window
  = 256` is deliberately small for local compute; raise it only if asked.
- **`test.lua`** — walks up from the test file to find `jest.config.{ts,js}` and configures neotest
  from that directory. Monorepo-aware by design.
- **`dap.lua`** — `pwa-node` adapter resolved through `mason-registry:get_install_path()`, so it
  breaks if `js-debug-adapter` isn't installed via Mason.
- **`dashboard.lua`** — the "SCOTTVIM" ASCII header is rendered by piping it through
  `echo -e "..." | lolcat -p 1` as a snacks `terminal` section, so **the dashboard needs `lolcat`
  installed** (`brew install lolcat`) or the header comes up empty. `toEchoLolcat()` does the
  line-joining.
- **`blink-cmp.lua` snippet loading is fragile** — `lazy_load({ paths = { "./snippets" } })` uses a
  *relative* path, so it only resolves when nvim's cwd happens to be the config dir. It also defines
  `c` / `el` / `comp` snippets programmatically in Lua that duplicate entries in
  `snippets/ts.json` / `tsx.json`. If snippets misbehave, that overlap is the first place to look;
  the relative path should become `vim.fn.stdpath("config") .. "/snippets"`.
- **`init.lua` golangci-lint shim** — a `VimEnter` autocmd rewrites `lint.linters.golangcilint` to
  pass `run --out-format json` with a custom parser. Needed because the stock nvim-lint spec invokes
  the binary without `run`.
- **`lsp.lua` diagnostic filter** — wraps both `vim.diagnostic.show` and the
  `textDocument/publishDiagnostics` handler to swallow one specific ESLint
  `use-at-your-own-risk ... eslint-recommended-raw is not defined` message. Monkey-patching globals
  is intentional here; if you touch it, keep both layers or neither.

## Style

Tab-indented, stylua defaults (~120 col) — `stylua` is **not installed**, so match surrounding code
by hand. Double-quoted strings. `local` at top of file for constants (`NUM_RESULTS`, `DEBOUNCE_MS`
in `muninn.lua`). Type annotations via `---@type` / `---@module` where the plugin ships them
(`oil.lua`, `muninn.lua`).

## Verification

```sh
nvim --headless "+Lazy! sync" +qa        # installs/updates, surfaces spec errors
nvim --headless "+checkhealth" +qa       # LSP / provider / plugin health
nvim --headless "+Lazy! check" +qa       # what's out of date
```

To check one spec file without loading the whole config (verified read-only — `-u NONE` skips
`init.lua`, so nothing touches `lazy-lock.json`):

```sh
nvim --headless -u NONE "+lua local t = dofile('lua/plugins/<name>.lua'); print(type(t), #t)" +qa
```

Spec files are pure table returns, so this parses and evaluates them with no side effects; a
`table` + count means the file is valid Lua and returns a spec list.

Interactive checks worth doing for UI/keymap changes: `:Lazy` (load order, startup time),
`:LazyExtras`, `:messages` after launch, and actually pressing the new keymap. Report the real
output; a silent `Lazy! sync` is a pass, any `E5108`/spec error in stderr is not.

After a plugin add/remove/update, `lazy-lock.json` will be dirty — that's expected and should be
committed, not reverted.

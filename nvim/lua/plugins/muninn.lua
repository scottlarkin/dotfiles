-- Semantic file finder backed by the muninn code graph.
--
-- `<leader>ff` matches on path text; this matches on meaning ("where do we
-- parse jwt") by embedding the query and ANN-searching the indexed file nodes.
-- Requires the repo to have been indexed: `muninn index`.
--
-- live=true routes typed text to filter.search (not filter.pattern), so snacks'
-- fuzzy matcher stays out of the way and muninn's score order survives to the
-- list. Each keystroke aborts the in-flight process (proc handles that).

local NUM_RESULTS = 40

-- snacks THROTTLES the input (200ms, hardcoded in picker/core/input.lua) but
-- never debounces, so continuous typing keeps firing queries every window —
-- each one an ollama embed plus an ANN search. Sleeping inside the finder turns
-- that into a real debounce: a superseded task is aborted while suspended and
-- raises out of the sleep before it ever spawns muninn.
--
-- Must exceed the 200ms throttle interval, or the sleep finishes in the gap
-- between two fires and spawns anyway, which is the thing we're preventing.
local DEBOUNCE_MS = 250

-- nvim launched from a GUI may not inherit the shell PATH.
local function muninn_cmd()
	local exe = vim.fn.exepath("muninn")
	if exe ~= "" then
		return exe
	end
	local fallback = vim.fn.expand("~/go/bin/muninn")
	return vim.fn.executable(fallback) == 1 and fallback or nil
end

-- muninn scopes to the repo containing cwd, so the process must start inside it.
local function root_dir()
	local ok, root = pcall(function()
		return LazyVim.root()
	end)
	return (ok and root) or vim.fn.getcwd()
end

-- Repo-scoped only: muninn stores no absolute path on file nodes, so `--global`
-- hits from other repos can't be resolved to a local file and get dropped.
local function finder(opts, ctx)
	local search = vim.trim(ctx.filter.search or "")
	if search == "" then
		return {}
	end

	local cmd = muninn_cmd()
	if not cmd then
		Snacks.notify.error("muninn not found on PATH")
		return {}
	end

	-- `--pos` appends `:<line>` (start of the best-matching symbol in the file);
	-- `--` so a query starting with `-` isn't parsed as a flag.
	local args = { "files", "--score", "--pos", "-n", tostring(opts.n or NUM_RESULTS), "--", search }

	-- Builds the closure only; muninn is not spawned until it is called below.
	local run = require("snacks.picker.source.proc").proc({
		cmd = cmd,
		args = args,
		cwd = root_dir(),
		-- Emits "<abs path>[:<line>]\t<score>"; drop anything else (a stray log
		-- line) rather than showing it as an unopenable entry. The `:<line>` is
		-- absent for files with no embedded symbols, so it stays optional.
		transform = function(item)
			local rest, score = tostring(item.text):match("^(.+)\t([%d.]+)$")
			if not rest then
				return false
			end
			-- Greedy `.+` leaves the LAST `:digits`, so a path containing a colon
			-- still splits correctly.
			local path, line = rest:match("^(.+):(%d+)$")
			item.file = path or rest
			item.text = item.file
			if line then
				-- `pos`, not `line`: snacks treats item.line as line *content*.
				item.pos = { tonumber(line), 0 }
			end
			item.muninn_score = tonumber(score)
			return item
		end,
	}, ctx)

	---@async
	return function(cb)
		local async = require("snacks.picker.util.async").running()
		if async then
			async:sleep(DEBOUNCE_MS)
		end
		return run(cb)
	end
end

-- format.file already renders item.pos as ":<line>"; only the score is ours.
local function format(item, picker)
	local ret = Snacks.picker.format.file(item, picker)
	if item.muninn_score then
		ret[#ret + 1] = { ("  %.2f"):format(item.muninn_score), "SnacksPickerComment" }
	end
	return ret
end

return {
	{
		"folke/snacks.nvim",
		optional = true,
		opts = {
			picker = {
				sources = {
					---@type snacks.picker.Config
					muninn = {
						finder = finder,
						format = format,
						title = "Muninn Semantic",
						live = true,
						supports_live = true,
						show_empty = true,
						n = NUM_RESULTS,
					},
				},
			},
		},
		-- stylua: ignore
		keys = {
			{ "<leader>fm", function() Snacks.picker.pick("muninn") end, desc = "Muninn Semantic Find" },
		},
	},
}

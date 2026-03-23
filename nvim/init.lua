require("config.lazy")

local map = vim.keymap.set

-- map jk to escape; TODO - do this in keyboard firmware
map("i", "jk", "<esc>", { remap = true })

map("n", "<leader>h", vim.lsp.buf.hover, { noremap = true, silent = true })

-- exit terminal mode with escape
map("t", "<esc>", "<C-\\><C-n>", { noremap = true, silent = true })

-- map("n", "<CR>", "o<esc>", { noremap = true, silent = true })

map("n", "<BS>", "<C-o>", { noremap = true, silent = true })

map("n", "<Del>", "<C-i>", { noremap = true, silent = true })

map("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })

-- recenter cursor when scrolling up/down
map("n", "<C-u>", "<C-u>zz", { noremap = true, silent = true })
map("n", "<C-d>", "<C-d>zz", { noremap = true, silent = true })

function SetTheme(color)
	color = color or "tokyonight-night"
	vim.cmd.colorscheme(color)
end

SetTheme()

-- Fix golangci-lint invocation for nvim-lint plugin
-- This ensures 'golangci-lint run' is called instead of just 'golangci-lint'
vim.api.nvim_create_autocmd({ "VimEnter" }, {
	callback = function()
		local ok, lint = pcall(require, "lint")
		if ok then
			lint.linters.golangcilint = {
				cmd = "golangci-lint",
				args = { "run", "--out-format", "json" },
				stdin = false,
				stream = "stdout",
				ignore_exitcode = false,
				parser = function(output, bufnr)
					local decoded = vim.json.decode(output)
					if not decoded or not decoded.Issues then
						return {}
					end

					local diagnostics = {}
					for _, issue in ipairs(decoded.Issues) do
						table.insert(diagnostics, {
							lnum = (issue.Pos.Line or 1) - 1,
							col = (issue.Pos.Column or 1) - 1,
							end_lnum = (issue.Pos.Line or 1) - 1,
							end_col = (issue.Pos.Column or 1) - 1,
							severity = vim.diagnostic.severity.WARN,
							source = "golangci-lint",
							message = issue.Text,
							code = issue.FromLinter,
						})
					end
					return diagnostics
				end,
			}
		end
	end,
})

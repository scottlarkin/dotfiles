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

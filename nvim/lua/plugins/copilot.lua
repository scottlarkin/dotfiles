return {
	-- {
	-- 	"zbirenbaum/copilot.lua",
	-- 	opts = function(_, opts)
	-- 		opts.suggestion.enabled = true
	-- 		opts.suggestion.hide_during_completion = false
	-- 		opts.suggestion.keymap = {
	-- 			accept = "<tab>",
	-- 			next = "<M-]>",
	-- 			prev = "<M-[>",
	-- 		}
	-- 		return opts
	-- 	end,
	-- },

	-- {
	-- 	"copilotlsp-nvim/copilot-lsp",
	-- 	init = function()
	-- 		vim.g.copilot_nes_debounce = 300
	-- 		vim.lsp.enable("copilot")
	-- 		vim.keymap.set("n", "<tab>", function()
	-- 			require("copilot-lsp.nes").apply_pending_nes()
	-- 		end)
	-- 	end,
	-- },
}

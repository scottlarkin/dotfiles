return {
	{
		"numToStr/FTerm.nvim",
		config = function()
			local fterm = require("FTerm")
			vim.keymap.set("n", "<leader>T", function()
				fterm:toggle()
			end, { desc = "[T]oggle [T]terminal" })
			vim.keymap.set("t", "<leader>T", function()
				fterm:toggle()
			end, { desc = "[T]oggle [T]erminal" })
		end,
	},
}

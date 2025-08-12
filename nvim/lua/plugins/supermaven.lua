return {
	"supermaven-inc/supermaven-nvim",
	opts = function(_, opts)
		opts.disable_inline_completion = false
		opts.keymaps = {
			accept_suggestion = "<C-a>",
			clear_sugestions = "<C-c>",
		}

		return opts
	end,
}

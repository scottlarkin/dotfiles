require("noice").setup({
	routes = {
		{
			filter = {
				event = "msg_show",
				find = "pattern not found", -- Replace with part of your error message
			},
			opts = { skip = true },
		},
	},
})

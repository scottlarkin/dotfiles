local header
header = [[
              ██████╗ ██████╗ ██████╗ ████████╗████████╗██╗   ██╗██╗███╗   ███╗
              ██╔════╝██╔════╝██╔═══██╗╚══██╔══╝╚══██╔══╝██║   ██║██║████╗ ████║
              ███████╗██║     ██║   ██║   ██║      ██║   ██║   ██║██║██╔████╔██║
              ╚════██║██║     ██║   ██║   ██║      ██║   ╚██╗ ██╔╝██║██║╚██╔╝██║
              ███████║╚██████╗╚██████╔╝   ██║      ██║    ╚████╔╝ ██║██║ ╚═╝ ██║
              ╚══════╝ ╚═════╝ ╚═════╝    ╚═╝      ╚═╝     ╚═══╝  ╚═╝╚═╝     ╚═╝
]]

local function toEchoLolcat(str)
	-- Split the string into lines
	local lines = {}
	for line in str:gmatch("[^\n]+") do
		table.insert(lines, line)
	end

	-- Join lines with \n and wrap in echo -e "..."
	local joined = table.concat(lines, "\\n")
	local result = 'echo -e "' .. joined .. '" | lolcat -p 1'
	return result
end

return {
	{
		"folke/snacks.nvim",
		optional = true,
		opts = {
			picker = {
				sources = {
					files = { hidden = true },
				},
			},
			dashboard = {
				width = 90,
				preset = {
					header = [[]],
					keys = {
						{
							icon = " ",
							desc = "Find File",
							action = ":lua Snacks.dashboard.pick('files')",
							key = "f",
						},
						{ icon = " ", desc = "New File", action = ":ene | startinsert", key = "n" },
						{
							icon = " ",
							desc = "Recent Files",
							action = ":lua Snacks.dashboard.pick('oldfiles')",
							key = "r",
						},
						{
							icon = " ",
							desc = "Find Text",
							action = ":lua Snacks.dashboard.pick('live_grep')",
							key = "g",
						},
						{
							icon = " ",
							desc = "Config",
							action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
							key = "c",
						},
						{ icon = "󰦛 ", key = "s", desc = "Restore Session", section = "session" },
						{
							icon = "󰁯 ",
							action = function()
								require("persistence").load({ last = true })
							end,
							desc = "Restore Last Session",
							key = "S",
						},
						{ icon = " ", desc = "Lazy Extras", action = ":LazyExtras", key = "x" },
						{ icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy", enabled = package.loaded.lazy },
						{ icon = " ", key = "q", desc = "Quit", action = ":qa" },
					},
				},
				formats = {
					header = { enabled = false },
				},
				sections = {
					{ section = "header", hidden = true },
					{
						section = "terminal",
						cmd = toEchoLolcat(header),
						height = 8,
						width = 100,
					},
					{
						section = "terminal",
						cmd = "echo ''",
						width = 100,
						height = 5,
					},
					{ section = "keys", gap = 1, padding = 1, width = 60 },
					{ section = "startup" },
				},
			},
		},
	},
}

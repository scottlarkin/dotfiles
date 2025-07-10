return {
	{
		"mfussenegger/nvim-dap",
		config = function()
			local dap = require("dap")

			-- Define the adapter for pwa-node
			dap.adapters["pwa-node"] = {
				type = "server",
				host = "localhost",
				port = "${port}",
				executable = {
					command = "node",
					args = {
						require("mason-registry").get_package("js-debug-adapter"):get_install_path()
							.. "/js-debug/src/dapDebugServer.js",
						"${port}",
					},
				},
			}

			local js_filetypes = { "typescript", "javascript" }
			for _, language in ipairs(js_filetypes) do
				dap.configurations[language] = {
					{
						type = "pwa-node",
						request = "attach",
						name = "atttach to postgraphile",
						port = 9678,
						address = "localhost",
						cwd = "${workspaceFolder}",
						sourceMaps = true,
						skipFiles = { "<node_internals>/**" },
					},
				}
			end
		end,
	},

	{
		"rcarriga/nvim-dap-ui",
		dependencies = { "nvim-neotest/nvim-nio" },
    -- stylua: ignore
    keys = {
      { "<leader>du", function() require("dapui").toggle({ }) end, desc = "Dap UI" },
      { "<leader>de", function() require("dapui").eval() end, desc = "Eval", mode = {"n", "v"} },
    },
		opts = {
			layouts = {
				{
					elements = {
						-- Provide as ID strings or tables with "id" and "size" keys
						{
							id = "scopes",
							size = 0.25, -- Can be float or integer > 1
						},
						{ id = "breakpoints", size = 0.25 },
						{ id = "stacks", size = 0.25 },
						{ id = "watches", size = 00.25 },
					},
					size = 40,
					position = "left",
				},
			},
		},
		config = function(_, opts)
			local dap = require("dap")
			local dapui = require("dapui")

			dapui.setup(opts)
			dap.listeners.after.event_initialized["dapui_config"] = function()
				dapui.open({})
			end
			dap.listeners.before.event_terminated["dapui_config"] = function()
				dapui.close({})
			end
			dap.listeners.before.event_exited["dapui_config"] = function()
				dapui.close({})
			end
		end,
	},
}

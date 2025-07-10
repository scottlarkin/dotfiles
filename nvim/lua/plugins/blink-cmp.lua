return {

	{
		"rafamadriz/friendly-snippets",
		config = function()
			-- require("luasnip.loaders.from_vscode").lazy_load()
			-- load snippets from path/of/your/nvim/config/my-cool-snippets
			require("luasnip.loaders.from_vscode").lazy_load({ paths = { "./snippets" } })
			-- Filter out copyright snippets
			local ls = require("luasnip")

			local s = ls.snippet
			local t = ls.text_node
			local i = ls.insert_node
			local f = ls.function_node

			ls.add_snippets("typescript", {
				s("c", {
					t("const "),
					i(1, "name"),
					t(" = "),
					i(2, "value"),
				}),
			}, {
				key = "typescript",
				priority = 5000,
			})

			local function fn(
				args, -- text from i(2) in this example i.e. { { "456" } }
				parent, -- parent snippet or parent node
				user_args -- user_args from opts.user_args
			)
				return args[1][1]
			end

			ls.add_snippets("typescriptreact", {
				s("comp", {
					t("type "),
					f(fn, { 1 }, {}),
					t({ "Props = {};", "", "" }),
					t("export const "),
					i(1, "ComponentName"),
					t(" = ({}:"),
					f(fn, { 1 }, {}),
					t("Props) => {};"),
				}),
			}, {
				key = "tsx",
				priority = 5000,
			})

			ls.add_snippets("typescriptreact", {
				s("el", {
					t("<"),
					i(1, "El"),
					t({ ">", "" }),
					i(0, ""),
					t("</"),
					f(fn, { 1 }, {}),
					t(">"),
				}),
			}, {
				key = "tsx",
				priority = 5000,
			})
			-- Explicitly set up TypeScript filetype associations
			-- ls.filetype_extend("typescript", { "javascript" })
			-- ls.filetype_extend("typescriptreact", { "javascript", "typescript" })
			-- ls.filetype_extend("tsx", { "javascript", "typescript", "typescriptreact" })
		end,
	},
	{
		-- "saghen/blink.cmp",
		--
		-- opts = {
		-- 	snippets = {
		-- 		preset = "luasnip",
		-- 		sources = {},
		-- 	},
		-- },
		"saghen/blink.cmp",

		dependencies = { "L3MON4D3/LuaSnip", version = "v2.*" },
		opts = function(_, opts)
			opts.snippets = { preset = "luasnip" }
			opts.sources = {
				default = { "snippets", "lsp", "buffer" },
			}
			-- opts.completion.ghost_text = { enabled = false }
			return opts
		end,
	},
}

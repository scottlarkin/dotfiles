return {
	{
		"neovim/nvim-lspconfig",
		opts = {
			inlay_hints = { enabled = false },
			servers = {
				eslint = {
					settings = {
						workingDirectories = { mode = "auto" },
						run = "onSave", -- Type-aware rules are slow; only lint on save
						-- Nested under eslint key as some versions expect this
						eslint = {
							run = "onSave",
							quiet = true, -- Ignore warnings, only show errors
						},
					},
				},
				vtsls = {
					settings = {
						typescript = {
							-- Reduce TypeScript LSP update frequency
							updateImportsOnFileMove = { enabled = "never" },
						},
					},
				},
			},
		},
		init = function()
			-- Filter out the specific ESLint subpath error using diagnostic config
			vim.diagnostic.config({
				-- Filter function to exclude the specific error
				severity_sort = true,
				signs = true,
				underline = true,
				update_in_insert = false,
				virtual_text = true,
				float = {
					source = true,
				},
			})

			-- Alternative approach: Filter diagnostics globally
			local original_show = vim.diagnostic.show
			vim.diagnostic.show = function(namespace, bufnr, diagnostics, opts)
				if diagnostics then
					diagnostics = vim.tbl_filter(function(diagnostic)
						if diagnostic.message then
							-- Match the specific ESLint subpath error
							return not string.match(
								diagnostic.message,
								"use%-at%-your%-own%-risk.*eslint%-recommended%-raw.*is not defined"
							)
						end
						return true
					end, diagnostics)
				end
				return original_show(namespace, bufnr, diagnostics, opts)
			end

			-- Also filter at the LSP handler level for completeness
			local original_publish = vim.lsp.handlers["textDocument/publishDiagnostics"]
			vim.lsp.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx, config)
				if result and result.diagnostics then
					result.diagnostics = vim.tbl_filter(function(diagnostic)
						if diagnostic.message then
							return not string.match(
								diagnostic.message,
								"use%-at%-your%-own%-risk.*eslint%-recommended%-raw.*is not defined"
							)
						end
						return true
					end, result.diagnostics)
				end
				return original_publish(err, result, ctx, config)
			end
		end,
	},
}

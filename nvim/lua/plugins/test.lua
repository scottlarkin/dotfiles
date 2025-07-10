local function find_jest_config_dir(test_file)
	-- Get the directory of the test file
	local current_dir = vim.fn.fnamemodify(test_file, ":h")

	-- Traverse up the directory tree until the root
	while current_dir ~= "/" do
		-- Check for TypeScript config
		local ts_config_path = current_dir .. "/jest.config.ts"
		if vim.loop.fs_stat(ts_config_path) then
			return current_dir, "ts"
		end

		-- Check for JavaScript config
		local js_config_path = current_dir .. "/jest.config.js"
		if vim.loop.fs_stat(js_config_path) then
			return current_dir, "js"
		end

		-- Move to the parent directory
		current_dir = vim.fn.fnamemodify(current_dir, ":h")
	end

	-- Final check at the root directory
	local ts_config_path = current_dir .. "/jest.config.ts"
	local js_config_path = current_dir .. "/jest.config.js"

	if vim.loop.fs_stat(ts_config_path) then
		return current_dir, "ts"
	elseif vim.loop.fs_stat(js_config_path) then
		return current_dir, "js"
	end

	-- Return nil if no jest config is found
	return nil, nil
end

return {
	{ "nvim-neotest/neotest-jest" },
	{ "thenbe/neotest-playwright" },
	{
		"nvim-neotest/neotest",
		opts = {
			adapters = {
				-- ["neotest-playwright"] = {
				-- 	options = {
				-- 		-- Use this to customize the command to run when using Playwright.
				-- 		-- For example, use pnpm or yarn instead of npm
				-- 		command = "pnpm test --",
				-- 		-- Set this to true to show error messages in a notification
				-- 		errorMessages = true,
				-- 		get_playwright_config = function()
				-- 			return vim.loop.cwd() .. "/playwright.config.ts"
				-- 		end,
				-- 		-- Optional patterns to match test files, defaults to:
				-- 		-- Optional test patterns to match test files, defaults to:
				--
				-- 		is_test_file = function(file)
				-- 			-- Check if the file is a test file
				-- 			return true
				-- 		end,
				-- 	},
				-- },
				["neotest-jest"] = {
					jestCommand = "pnpm test --",
					jestConfigFile = function(file)
						--try to resolve the correct jest config for this project
						if string.find(file, "___tests___") then
							local dir = string.match(file, "(.-/[^/]+/)__tests__")
							local ts_path = dir .. "jest.config.ts"
							local js_path = dir .. "jest.config.js"

							if vim.loop.fs_stat(ts_path) then
								return ts_path
							elseif vim.loop.fs_stat(js_path) then
								return js_path
							else
								return ts_path -- default to ts if not found
							end
						end

						if string.find(file, ".test.ts") or string.find(file, ".test.js") then
							local dir, type = find_jest_config_dir(file)
							if dir and type then
								return dir .. "/jest.config." .. type
							end
						end

						-- Check current directory for both types
						local cwd = vim.fn.getcwd()
						local ts_path = cwd .. "/jest.config.ts"
						local js_path = cwd .. "/jest.config.js"

						if vim.loop.fs_stat(ts_path) then
							return ts_path
						elseif vim.loop.fs_stat(js_path) then
							return js_path
						else
							return ts_path -- default to ts if not found
						end
					end,
					cwd = function(file)
						if string.find(file, "/__tests__/") then
							return string.match(file, "(.-/[^/]+/)__tests__")
						end
						if string.find(file, ".test.ts") or string.find(file, ".test.js") then
							local dir, _ = find_jest_config_dir(file)
							return dir
						end

						return vim.fn.getcwd()
					end,
				},
			},
		},
	},
}

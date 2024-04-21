local M = {}

M.popup_manager = require("simple-popup")
M.popup_app_id = "github-chatpilot"
M.queries = {}

M.setup = function()
	vim.api.nvim_create_user_command("GithubChatPilotExplain", "lua require('github-chatpilot').explain()", {})
	vim.api.nvim_create_user_command("GithubChatPilotHistory", "lua require('github-chatpilot').history()", {})
	vim.api.nvim_create_user_command(
		"GithubChatPilotFlushHistory",
		"lua require('github-chatpilot').flushQueries()",
		{}
	)
	vim.keymap.set("n", "<leader><leader>ghce", "<cmd>Lazy reload github-chatpilot.nvim<cr>")
	vim.keymap.set("n", "<leader>ghce", "<cmd>GithubChatPilotExplain<cr>")
	vim.keymap.set("n", "<leader>ghch", "<cmd>GithubChatPilotHistory<cr>")
end

M.explain = function()
	M.popup_manager.deleteAllWindows(M.popup_app_id)

	M.popup_manager.createPopup(
		M.popup_app_id,
		"textbox",
		"none",
		"How can I help you?",
		{ "This is an example input to calculate the length of the input fiels.", "", "", "", "" },
		"lua",
		M.handleUserInputKeepQuery
	)
end

M.history = function()
	M.popup_manager.deleteAllWindows(M.popup_app_id)

	if M.queries[1] == nil then
		M.popup_manager.createPopup(
			M.popup_app_id,
			"output",
			"none",
			"Empty History",
			{ "Your query history is empty.", "Start doing your first query." }
		)
	else
		M.popup_manager.createPopup(
			M.popup_app_id,
			"select",
			"none",
			"Query History",
			M.queries,
			"lua",
			M.handleUserInput
		)
	end
end

M.flushQueries = function()
	M.queries = {}
end

M.handleUserInputKeepQuery = function(input)
	M.handleUserInput(input, true)
end

---comment
---@param query string
M.addQueryToHistory = function(query)
	for s in query:gmatch("[^\r\n]+") do
		local line = vim.fn.trim(s)
		if line ~= "" then
			table.insert(M.queries, s .. " ...")

			return
		end
	end
end

---comment
---@param input string
---@param keep_query any
M.handleUserInput = function(input, keep_query)
	if input == nil then
		return
	end

	if keep_query == true then
		M.addQueryToHistory(input)
	end

	local command = "!gh copilot explain " .. input:gsub("([^%w])", "\\%1")
	print("Copilot is looking for an answer ...")

	local cmd = vim.api.nvim_parse_cmd(command, {})
	local result = vim.api.nvim_cmd(cmd, { output = true })

	if result == nil then
		print("Error: No result")
		return
	end

	if vim.v.shell_error ~= 0 then
		print("Error: " .. result)
		return
	end

	-- delete everything from result until "# Explanation"
	local start = string.find(result, "# Explanation")
	if start ~= nil then
		result = string.sub(result, start)
		-- remove first two lines
		result = result:gsub("(.-\n)", "", 2)
	end

	local lines = { "Question:" }

	-- split the input into lines
	for s in input:gmatch("[^\n]+") do
		table.insert(lines, "\t" .. s)
	end

	-- split the result into lines
	table.insert(lines, "")
	table.insert(lines, "Answer:")
	for s in result:gmatch("[^\r\n]+") do
		table.insert(lines, s)
	end

	M.popup_manager.createPopup(M.popup_app_id, "output", "none", "", lines, "lua")
end

return M

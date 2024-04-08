local buffer = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_keymap(buffer, "n", "q", ":q<CR>", {})
vim.api.nvim_buf_set_keymap(buffer, "v", "q", ":q<CR>", {})
local editor_width = vim.api.nvim_list_uis()[1].width
local editor_height = vim.api.nvim_list_uis()[1].height

local M = {}

M.answer_win_id = nil
M.question_win_id = nil

M.setup = function()
  print("github chatpilot setup")
  vim.api.nvim_create_user_command("GithubChatPilot", "lua require('github-chatpilot').toggle()", {})
  vim.keymap.set("n", "<leader>ghce", '<cmd>lua require("github-chatpilot").toggle()<cr>')
  vim.keymap.set("n", "<leader>Rghcp", "<cmd>Lazy reload github-chatpilot.nvim<cr>")

  vim.keymap.set("n", "<leader>ggg", '<cmd>lua require("github-chatpilot").toggle()<cr>')
  vim.keymap.set("n", "<leader>ttt", '<cmd>lua require("github-chatpilot").test()<cr>')
  vim.keymap.set("n", "<leader>rrr", "<cmd>Lazy reload github-chatpilot.nvim<cr>")
end

M.test = function()
  vim.api.nvim_buf_set_option(buffer, "modifiable", true)
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, {})
  vim.api.nvim_buf_set_keymap(buffer, "n", "q", ":q<CR>", {})
  vim.api.nvim_buf_set_keymap(buffer, "v", "q", ":q<CR>", {})
  vim.api.nvim_buf_set_keymap(
    buffer,
    "i",
    "<CR>",
    "<cmd>lua require('github-chatpilot').handleUserInput(vim.fn.getline('.'))<CR>",
    {}
  )

  local win_width = 60
  local win_height = 1

  M.question_win_id = vim.api.nvim_open_win(buffer, true, {
    relative = "editor",
    width = win_width,
    height = win_height,
    row = vim.fn.floor((editor_height - win_height) * 0.5),
    col = vim.fn.floor((editor_width - win_width) * 0.5),
    style = "minimal",
    border = "single",
    title = "How can I help you?",
    title_pos = "left",
  })

  vim.cmd("startinsert")
end

M.closeQuestionWindow = function()
  vim.api.nvim_buf_del_keymap(buffer, "i", "<CR>")
  vim.cmd("stopinsert")

  if vim.api.nvim_win_is_valid(M.question_win_id) then
    vim.api.nvim_win_close(M.question_win_id, true)
  end

  M.question_win_id = nil
end

M.closeAnswerWindow = function()
  if vim.api.nvim_win_is_valid(M.answer_win_id) then
    vim.api.nvim_win_close(M.answer_win_id, true)
  end

  M.answer_win_id = nil
end

M.handleUserInput = function(input)
  M.closeQuestionWindow()

  if input == nil then
    return
  end

  input = vim.fn.trim(input)
  if input == "" then
    return
  end

  local command = '!gh copilot explain "' .. input .. '"'
  print('running command:', command)

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

  -- split the result into lines
  local lines = {}
  for s in result:gmatch("[^\r\n]+") do
    table.insert(lines, s)
  end

  local longest_line = 0
  for _, line in ipairs(lines) do
    if #line > longest_line then
      longest_line = #line
    end
  end

  local win_width = longest_line + 10
  local win_height = #lines

  M.answer_win_id = vim.api.nvim_open_win(buffer, true, {
    relative = "editor",
    width = win_width,
    height = win_height,
    row = vim.fn.floor((editor_height - win_height) * 0.5),
    col = vim.fn.floor((editor_width - win_width) * 0.5),
    style = "minimal",
    border = "single",
    title = input
  })

  vim.api.nvim_buf_set_option(buffer, "modifiable", true)
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buffer, "modifiable", false)
end

M.start = function()
  vim.ui.input({ prompt = "How can I help you?\n> " }, M.handleUserInput)
end

M.stop = function()
  M.closeQuestionWindow()
  M.closeAnswerWindow()
end

M.toggle = function()
  if M.answer_win_id == nil then
    M.start()
  else
    M.stop()
    return
  end
end

return M

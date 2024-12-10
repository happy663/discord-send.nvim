local M = {}
M.config = {
	env_file_path = "~/.config/nvim/.env",
	notification = true,
}

local function notify(message, level)
	if M.config.notification then
		vim.notify(message, level)
	end
end

local function load_env(env_file_path)
	local env_file = vim.fn.expand(env_file_path)

	if vim.fn.filereadable(env_file) == 1 then
		for line in io.lines(env_file) do
			if line:match("^[^#]") then
				local key, value = line:match("([^=]+)=(.+)")
				if key and value then
					-- 前後の空白を削除
					key = key:gsub("^%s*(.-)%s*$", "%1")
					value = value:gsub("^%s*(.-)%s*$", "%1")
					-- 環境変数を設定
					vim.fn.setenv(key, value)
				end
			end
		end
	end
end

local function send_to_discord(message)
	local webhook_url = vim.fn.getenv("DISCORD_WEBHOOK_URL")
	-- メッセージデータを作成
	local data = {
		content = message,
	}
	local json_data = vim.fn.json_encode(data)
	local curl_command =
		string.format("curl -X POST -H \"Content-Type: application/json\" -d '%s' %s", json_data, webhook_url)

	notify("送信するJSON" .. json_data)

	local result = vim.fn.system(curl_command)

	if vim.v.shell_error ~= 0 then
		notify("Discord送信エラー" .. result, vim.log.levels.ERROR)
	end

	notify("messageを送信しました")
end

local function create_discord_buffer()
	vim.cmd("edit `=tempname()`")
	local bufnr = vim.api.nvim_get_current_buf()
	vim.api.nvim_create_autocmd("BufWritePost", {
		buffer = bufnr,
		callback = function()
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			local content = table.concat(lines, "\n")
			if content ~= "" then
				send_to_discord(content)
			end
		end,
	})
end

function M.setup(config)
	M.config = vim.tbl_deep_extend("force", M.config, config or {})
	load_env(M.config.env_file_path)

	-- コマンドの設定
	vim.api.nvim_create_user_command("DiscordSendBuffer", create_discord_buffer, {
		desc = "Create Discord message buffer",
	})

	vim.api.nvim_create_user_command("DiscordSend", function(opts)
		local message = opts.args
		if message == "" then
			notify("メッセージを入力してください")
			return
		end
		send_to_discord(message)
	end, {
		nargs = "+",
		desc = "Send message to discord",
	})

	-- キーマッピングの設定
	vim.keymap.set("n", "<leader>dsb", create_discord_buffer, {
		noremap = true,
		silent = true,
		desc = "Create Discord message buffer",
	})

	vim.keymap.set("n", "<leader>dsu", function()
		vim.ui.input({ prompt = "メッセージを入力してください" }, function(input)
			if input and input ~= "" then
				send_to_discord(input)
			end
		end)
	end, {
		noremap = true,
		silent = true,
		desc = "Send message to discord",
	})
end

M.send = send_to_discord
M.notify = notify

return M

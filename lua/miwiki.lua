--[[
 * miwiki - follow or create wikilink pages on <CR>
 * License: GPLv3
]]

local function parse_target(inner)
	local page

	inner = vim.trim(inner)
	page = inner:match('^([^|#]+)')
	if not page then
		return nil
	end
	page = vim.trim(page):gsub('%.md$', '')
	if page == '' then
		return nil
	end
	return page
end

local function wikilink_at_cursor()
	local line, col, from, s, e, inner

	line = vim.api.nvim_get_current_line()
	col = vim.api.nvim_win_get_cursor(0)[2] + 1
	from = 1
	while true do
		s, e, inner = line:find('%[%[([^%]]+)%]%]', from)
		if not s then
			return nil
		end
		if col >= s and col <= e then
			return parse_target(inner)
		end
		from = e + 1
	end
end

local function word_at_cursor()
	local line, col, s, e

	line = vim.api.nvim_get_current_line()
	col = vim.api.nvim_win_get_cursor(0)[2] + 1
	if line == '' then
		return nil
	end
	if col > #line then
		col = #line
	end
	if not line:sub(col, col):match('[%w._-]') then
		return nil
	end
	s, e = col, col
	while s > 1 and line:sub(s - 1, s - 1):match('[%w._-]') do
		s = s - 1
	end
	while e < #line and line:sub(e + 1, e + 1):match('[%w._-]') do
		e = e + 1
	end
	return s, e, line:sub(s, e)
end

local function wrap_range(s, e, text)
	local line

	line = vim.api.nvim_get_current_line()
	line = line:sub(1, s - 1) .. '[[' .. text .. ']]'
	    .. line:sub(e + 1)
	vim.api.nvim_set_current_line(line)
end

local function visual_range()
	local a, b, sr, sc, er, ec, text

	a = vim.fn.getpos('v')
	b = vim.fn.getpos('.')
	sr, sc, er, ec = a[2], a[3], b[2], b[3]
	if sr > er or (sr == er and sc > ec) then
		sr, sc, er, ec = er, ec, sr, sc
	end
	if sr ~= er then
		return nil
	end
	if vim.o.selection == 'exclusive' then
		ec = ec - 1
	end
	if ec < sc then
		return nil
	end
	text = vim.trim(vim.fn.getline(sr):sub(sc, ec))
	if text == '' then
		return nil
	end
	return sc, ec, text
end

local function page_path(name)
	return vim.fn.expand('%:p:h') .. '/' .. name .. '.md'
end

local function open_page(name, content_lines)
	local path, title, empty

	path = page_path(name)
	empty = vim.fn.filereadable(path) == 0
	if vim.bo.modified and vim.fn.expand('%') ~= '' then
		vim.cmd.write()
	end
	vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
	vim.cmd.edit(path)
	empty = empty or (vim.fn.line('$') == 1
	    and vim.api.nvim_get_current_line() == '')
	title = name:match('([^/]+)$') or name
	if empty then
		local lines = { '# ' .. title, '' }
		if content_lines and #content_lines > 0 then
			for _, l in ipairs(content_lines) do
				table.insert(lines, l)
			end
		else
			table.insert(lines, '')
		end
		vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
		vim.api.nvim_win_set_cursor(0, { 3, 0 })
	elseif content_lines and #content_lines > 0 then
		local count = vim.api.nvim_buf_line_count(0)
		local last_line = vim.api.nvim_buf_get_lines(0, count - 1, count, false)[1] or ''
		local lines = {}
		if last_line ~= '' then
			table.insert(lines, '')
		end
		for _, l in ipairs(content_lines) do
			table.insert(lines, l)
		end
		vim.api.nvim_buf_set_lines(0, count, count, false, lines)
		local target_row = count + (last_line ~= '' and 2 or 1)
		vim.api.nvim_win_set_cursor(0, { target_row, 0 })
	end
end

local function complete_notes(arg_lead)
	local dir = vim.fn.expand('%:p:h')
	local files = vim.fn.globpath(dir, '**/*.md', false, true)
	local current_file = vim.fn.expand('%:p')
	local prefix = dir .. '/'
	local matches = {}

	arg_lead = (arg_lead or ''):lower()
	for _, f in ipairs(files) do
		if f ~= current_file and f:sub(1, #prefix) == prefix then
			local note = f:sub(#prefix + 1):gsub('%.md$', '')
			if arg_lead == '' or note:lower():find(arg_lead, 1, true) == 1 then
				table.insert(matches, note)
			end
		end
	end
	table.sort(matches)
	return matches
end

local function move_to_note(opts)
	opts = opts or {}
	local in_visual = vim.fn.mode():match('^[vV\22]') ~= nil
	if in_visual then
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'nx', false)
	end

	local p1 = vim.fn.getpos("'<")
	local p2 = vim.fn.getpos("'>")
	local mode = vim.fn.visualmode()

	local line1 = opts.line1 or (in_visual and p1[2]) or vim.fn.line('.')
	local line2 = opts.line2 or (in_visual and p2[2]) or line1

	local is_charwise = (mode == 'v') and (p1[2] == line1) and (p2[2] == line2)

	local function execute_move(name)
		name = vim.trim(name):gsub('%.md$', '')
		if name == '' then
			return
		end

		local content_lines = {}
		local link = '[[' .. name .. ']]'

		if is_charwise then
			if p1[2] > p2[2] or (p1[2] == p2[2] and p1[3] > p2[3]) then
				p1, p2 = p2, p1
			end
			local end_line = vim.fn.getline(p2[2])
			local end_col = p2[3]
			if vim.o.selection ~= 'exclusive' then
				local next_char = vim.fn.strcharpart(end_line:sub(p2[3]), 0, 1)
				end_col = end_col + #next_char - 1
			end
			content_lines = vim.api.nvim_buf_get_text(0, p1[2] - 1, p1[3] - 1, p2[2] - 1, end_col, {})
			vim.api.nvim_buf_set_text(0, p1[2] - 1, p1[3] - 1, p2[2] - 1, end_col, { link })
		else
			content_lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
			vim.api.nvim_buf_set_lines(0, line1 - 1, line2, false, { link })
		end

		open_page(name, content_lines)
	end

	local arg_name = opts.args and vim.trim(opts.args) or ''
	if arg_name ~= '' then
		execute_move(arg_name)
	else
		vim.ui.input({
			prompt = 'Note name: ',
			completion = 'customlist,v:lua.require"miwiki".complete_notes',
		}, function(input)
			if not input then
				return
			end
			execute_move(input)
		end)
	end
end

local function follow_or_create()
	local target, s, e, word

	target = wikilink_at_cursor()
	if target then
		open_page(target)
		return true
	end
	s, e, word = word_at_cursor()
	if not word then
		return false
	end
	wrap_range(s, e, word)
	open_page(word)
	return true
end

local function follow_or_create_visual()
	local target, s, e, text

	target = wikilink_at_cursor()
	if target then
		vim.api.nvim_feedkeys('\27', 'nx', false)
		open_page(target)
		return true
	end
	s, e, text = visual_range()
	if not text then
		return false
	end
	vim.api.nvim_feedkeys('\27', 'nx', false)
	wrap_range(s, e, text)
	open_page(text)
	return true
end

local function smart_action()
	local ok

	if vim.fn.mode() == 'v' or vim.fn.mode() == 'V' then
		ok = follow_or_create_visual()
	else
		ok = follow_or_create()
	end
	if not ok then
		vim.cmd('normal! +')
	end
end

vim.api.nvim_create_autocmd('FileType', {
	group = vim.api.nvim_create_augroup('miwiki', { clear = true }),
	pattern = 'markdown',
	callback = function()
		vim.keymap.set({ 'n', 'v' }, '<CR>', smart_action, {
			buffer = true,
			desc = 'miwiki: follow or create link',
		})
	end,
})

local M = {
	follow_or_create = follow_or_create,
	follow_or_create_visual = follow_or_create_visual,
	smart_action = smart_action,
	move_to_note = move_to_note,
	complete_notes = complete_notes,
}

return M

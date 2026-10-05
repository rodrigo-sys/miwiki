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

local function open_page(name)
	local path, title, empty

	path = page_path(name)
	empty = vim.fn.filereadable(path) == 0
	if vim.bo.modified then
		vim.cmd.write()
	end
	vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
	vim.cmd.edit(path)
	empty = empty or (vim.fn.line('$') == 1
	    and vim.api.nvim_get_current_line() == '')
	if empty then
		title = name:match('([^/]+)$') or name
		vim.api.nvim_buf_set_lines(0, 0, -1, false, {
			'# ' .. title, '', '',
		})
		vim.api.nvim_win_set_cursor(0, { 3, 0 })
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

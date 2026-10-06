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

local function default_vault_dir()
	return vim.fs.normalize(vim.fn.expand(vim.g.miwiki_vault_dir or '~/miwiki'))
end

local function registry_file()
	return vim.fn.stdpath('state') .. '/miwiki_vaults.json'
end

local function load_registered_vaults()
	local path, f, content, ok, data

	path = registry_file()
	if vim.fn.filereadable(path) == 0 then
		return {}
	end
	f = io.open(path, 'r')
	if not f then
		return {}
	end
	content = f:read('*a')
	f:close()
	ok, data = pcall(vim.json.decode, content)
	if not ok or type(data) ~= 'table' then
		return {}
	end
	return data
end

local function save_registered_vaults(vaults)
	local path, dir, ok, json, f

	path = registry_file()
	dir = vim.fn.fnamemodify(path, ':h')
	vim.fn.mkdir(dir, 'p')
	ok, json = pcall(vim.json.encode, vaults)
	if not ok then
		return
	end
	f = io.open(path, 'w')
	if f then
		f:write(json)
		f:close()
	end
end

local function register_vault(dir)
	local list, normalized, seen, new_list

	normalized = vim.fs.normalize(dir)
	list = load_registered_vaults()
	seen = {}
	new_list = { normalized }
	seen[normalized] = true
	for _, p in ipairs(list) do
		if not seen[p] and vim.fn.isdirectory(p) == 1 then
			table.insert(new_list, p)
			seen[p] = true
		end
	end
	save_registered_vaults(new_list)
end

local function list_vaults()
	local base, subdirs, reg, vaults, seen, name

	base = default_vault_dir()
	vaults = {}
	seen = {}
	if vim.fn.isdirectory(base) == 1 then
		subdirs = vim.fn.globpath(base, '*', false, true)
		for _, p in ipairs(subdirs) do
			p = vim.fs.normalize(p)
			if vim.fn.isdirectory(p) == 1 and not seen[p] then
				name = vim.fn.fnamemodify(p, ':t')
				table.insert(vaults, { name = name, path = p })
				seen[p] = true
			end
		end
	end
	reg = load_registered_vaults()
	for _, p in ipairs(reg) do
		p = vim.fs.normalize(p)
		if vim.fn.isdirectory(p) == 1 and not seen[p] then
			name = vim.fn.fnamemodify(p, ':t')
			table.insert(vaults, { name = name, path = p })
			seen[p] = true
		end
	end
	return vaults
end

local function current_vault_root()
	local cur, vaults, best, p

	cur = vim.fn.expand('%:p')
	if cur == '' then
		cur = vim.fs.normalize(vim.fn.getcwd())
	else
		cur = vim.fs.normalize(vim.fn.fnamemodify(cur, ':h'))
	end
	vaults = list_vaults()
	best = nil
	for _, v in ipairs(vaults) do
		p = v.path
		if cur == p or cur:sub(1, #p + 1) == p .. '/' then
			if not best or #p > #best then
				best = p
			end
		end
	end
	return best
end

local function page_path(name)
	local cur_dir, cand, root

	cur_dir = vim.fn.expand('%:p:h')
	cand = cur_dir .. '/' .. name .. '.md'
	if vim.fn.filereadable(cand) == 1 then
		return cand
	end
	root = current_vault_root()
	if root and root ~= cur_dir then
		cand = root .. '/' .. name .. '.md'
		if vim.fn.filereadable(cand) == 1 then
			return cand
		end
	end
	return cur_dir .. '/' .. name .. '.md'
end


local function open_page(name, content)
	local path, title, empty, lines, count, last

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
		lines = { '# ' .. title, '' }
		if content and #content > 0 then
			for _, l in ipairs(content) do
				table.insert(lines, l)
			end
		else
			table.insert(lines, '')
		end
		vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
		vim.api.nvim_win_set_cursor(0, { 3, 0 })
		return
	end
	if not content or #content == 0 then
		return
	end
	count = vim.api.nvim_buf_line_count(0)
	last = vim.api.nvim_buf_get_lines(0, count - 1, count, false)[1] or ''
	lines = {}
	if last ~= '' then
		table.insert(lines, '')
	end
	for _, l in ipairs(content) do
		table.insert(lines, l)
	end
	vim.api.nvim_buf_set_lines(0, count, count, false, lines)
	vim.api.nvim_win_set_cursor(0, { count + (last ~= '' and 2 or 1), 0 })
end

local function is_url(target)
	local tld

	if target:match('^%a[%w+.-]*://') or target:match('^www%.')
	    or target:match('^mailto:') then
		return true
	end
	tld = target:match('^[%w_.-]+%.(%a+)[/#]?')
	if tld then
		tld = tld:lower()
		if tld == 'com' or tld == 'org' or tld == 'net' or tld == 'io'
		    or tld == 'dev' or tld == 'app' or tld == 'ai' or tld == 'co'
		    or tld == 'edu' or tld == 'gov' or tld == 'me' or tld == 'html'
		    or tld == 'htm' then
			return true
		end
	end
	return false
end

local function open_link(target)
	local clean, ext, page, url, path

	clean = target:match('^([^#]+)') or target
	if is_url(target) then
		url = (target:match('^%a+://') or target:match('^mailto:'))
		    and target or ('https://' .. target)
		vim.ui.open(url)
		return true
	end
	ext = clean:match('%.(%w+)$')
	if ext and ext:lower() ~= 'md' then
		path = vim.fs.normalize(vim.fn.expand('%:p:h') .. '/' .. clean)
		vim.ui.open(path)
		return true
	end
	page = parse_target(target)
	if page then
		open_page(page)
		return true
	end
	return false
end

local function link_at_cursor()
	local line, col, from, s, e, inner, text, target

	line = vim.api.nvim_get_current_line()
	col = vim.api.nvim_win_get_cursor(0)[2] + 1
	from = 1
	while true do
		s, e, inner = line:find('%[%[([^%]]+)%]%]', from)
		if not s then
			break
		end
		if col >= s and col <= e then
			return vim.trim(inner)
		end
		from = e + 1
	end
	from = 1
	while true do
		s, e, text, target = line:find('%[([^%]]+)%]%(([^%)]+)%)', from)
		if not s then
			break
		end
		if col >= s and col <= e then
			return vim.trim(target)
		end
		from = e + 1
	end
	return nil
end

local function complete_notes(lead)
	local root, dir, files, cur, pfx, matches, note

	root = current_vault_root()
	dir = root or vim.fn.expand('%:p:h')
	files = vim.fn.globpath(dir, '**/*.md', false, true)
	cur = vim.fn.expand('%:p')
	pfx = dir .. '/'
	matches = {}
	lead = (lead or ''):lower()
	for _, f in ipairs(files) do
		if f ~= cur and f:sub(1, #pfx) == pfx then
			note = f:sub(#pfx + 1):gsub('%.md$', '')
			if lead == '' or note:lower():find(lead, 1, true) then
				table.insert(matches, note)
			end
		end
	end
	table.sort(matches)
	return matches
end

_G.miwiki_complete_notes = complete_notes

local function cut_selection(opts, name)
	local p1, p2, mode, l1, l2, charwise, eline, ecol, nchar, lines, link

	p1 = vim.fn.getpos("'<")
	p2 = vim.fn.getpos("'>")
	mode = vim.fn.visualmode()
	l1 = opts.line1 or p1[2]
	l2 = opts.line2 or p2[2]
	charwise = (mode == 'v') and (p1[2] == l1) and (p2[2] == l2)
	link = '[[' .. name .. ']]'

	if charwise then
		if p1[2] > p2[2] or (p1[2] == p2[2] and p1[3] > p2[3]) then
			p1, p2 = p2, p1
		end
		eline = vim.fn.getline(p2[2])
		ecol = p2[3]
		if vim.o.selection ~= 'exclusive' then
			nchar = vim.fn.strcharpart(eline:sub(p2[3]), 0, 1)
			ecol = ecol + #nchar - 1
		end
		lines = vim.api.nvim_buf_get_text(0, p1[2] - 1, p1[3] - 1,
		    p2[2] - 1, ecol, {})
		vim.api.nvim_buf_set_text(0, p1[2] - 1, p1[3] - 1,
		    p2[2] - 1, ecol, { link })
		return lines
	end

	lines = vim.api.nvim_buf_get_lines(0, l1 - 1, l2, false)
	vim.api.nvim_buf_set_lines(0, l1 - 1, l2, false, { link })
	return lines
end

local function do_move(opts, name)
	local lines

	name = vim.trim(name):gsub('%.md$', '')
	if name == '' then
		return
	end
	lines = cut_selection(opts, name)
	open_page(name, lines)
end

local function move_to_note(opts)
	local arg, in_visual, p1, p2

	opts = opts or {}
	in_visual = vim.fn.mode():match('^[vV\22]') ~= nil
	if in_visual then
		vim.api.nvim_feedkeys('\27', 'nx', false)
	end
	if not opts.line1 then
		if in_visual then
			p1 = vim.fn.getpos("'<")
			p2 = vim.fn.getpos("'>")
			opts.line1 = p1[2]
			opts.line2 = p2[2]
		else
			opts.line1 = vim.fn.line('.')
			opts.line2 = opts.line1
		end
	end
	arg = opts.args and vim.trim(opts.args) or ''
	if arg ~= '' then
		do_move(opts, arg)
		return
	end
	vim.ui.input({
		prompt = 'Note name: ',
		completion = 'customlist,v:lua.miwiki_complete_notes',
	}, function(input)
		if input then
			do_move(opts, input)
		end
	end)
end

local function toggle_task_line(line)
	local pfx, mark, sfx

	pfx, mark, sfx = line:match('^(%s*[%-%*%+]%s+%[)(.)(%].*)$')
	if not pfx then
		pfx, mark, sfx = line:match('^(%s*%d+%.%s+%[)(.)(%].*)$')
	end
	if not pfx then
		return nil
	end
	mark = (mark == ' ') and 'x' or ' '
	return pfx .. mark .. sfx
end

local function toggle_visual_tasks()
	local a, b, sr, sc, er, ec, mode, line, sel, lines, changed, new_l

	mode = vim.fn.mode()
	a = vim.fn.getpos('v')
	b = vim.fn.getpos('.')
	sr, sc = a[2], a[3]
	er, ec = b[2], b[3]
	if sr > er or (sr == er and sc > ec) then
		sr, sc, er, ec = er, ec, sr, sc
	end
	if mode == 'v' and sr == er then
		line = vim.fn.getline(sr)
		sel = line:sub(sc, ec)
		if not sel:match('%[[%sxX]%]') and sc > 6 then
			return false
		end
	end
	lines = vim.api.nvim_buf_get_lines(0, sr - 1, er, false)
	changed = false
	for i, l in ipairs(lines) do
		new_l = toggle_task_line(l)
		if new_l then
			lines[i] = new_l
			changed = true
		end
	end
	if not changed then
		return false
	end
	vim.api.nvim_feedkeys('\27', 'nx', false)
	vim.api.nvim_buf_set_lines(0, sr - 1, er, false, lines)
	return true
end

local function follow_or_create()
	local target, s, e, word, line, new_l

	target = link_at_cursor()
	if target then
		return open_link(target)
	end
	line = vim.api.nvim_get_current_line()
	new_l = toggle_task_line(line)
	if new_l then
		vim.api.nvim_set_current_line(new_l)
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

	target = link_at_cursor()
	if target then
		vim.api.nvim_feedkeys('\27', 'nx', false)
		return open_link(target)
	end
	if toggle_visual_tasks() then
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
		vim.keymap.set({ 'n', 'v' }, '<leader>nm', move_to_note, {
			buffer = true,
			desc = 'miwiki: move to note',
		})
	end,
})

local function open_vault(path)
	local idx, full_idx, empty, title, lines

	path = vim.fs.normalize(path)
	if vim.fn.isdirectory(path) == 0 then
		vim.fn.mkdir(path, 'p')
	end
	register_vault(path)
	if vim.g.miwiki_vault_lcd ~= false then
		vim.cmd.lcd(path)
	end
	idx = vim.g.miwiki_index_name
	if idx == nil then
		idx = vim.g.miwiki_index or 'index.md'
	end
	if type(idx) == 'string' and vim.trim(idx) ~= '' then
		idx = vim.trim(idx):gsub('%.md$', '')
		full_idx = path .. '/' .. idx .. '.md'
		empty = vim.fn.filereadable(full_idx) == 0
		if vim.bo.modified and vim.fn.expand('%') ~= '' then
			vim.cmd.write()
		end
		vim.cmd.edit(full_idx)
		empty = empty or (vim.fn.line('$') == 1
		    and vim.api.nvim_get_current_line() == '')
		if empty then
			title = vim.fn.fnamemodify(path, ':t')
			lines = { '# ' .. title, '', '' }
			vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
			vim.api.nvim_win_set_cursor(0, { 3, 0 })
		end
	else
		vim.cmd.edit(path)
	end
end

local function create_vault(arg)
	local name, base, path

	if type(arg) == 'table' then
		name = arg.args and vim.trim(arg.args) or ''
	elseif type(arg) == 'string' then
		name = vim.trim(arg)
	else
		name = ''
	end

	base = default_vault_dir()
	if name == '' then
		vim.ui.input({ prompt = 'New vault name: ' }, function(input)
			if input and vim.trim(input) ~= '' then
				create_vault(input)
			end
		end)
		return
	end
	path = base .. '/' .. name
	open_vault(path)
end

local function init_cwd_vault(arg)
	local name, cwd, path

	if type(arg) == 'table' then
		name = arg.args and vim.trim(arg.args) or ''
	elseif type(arg) == 'string' then
		name = vim.trim(arg)
	else
		name = ''
	end

	cwd = vim.fs.normalize(vim.fn.getcwd())
	if name ~= '' then
		path = cwd .. '/' .. name
	else
		path = cwd
	end
	open_vault(path)
end

local function choose_vault(arg)
	local name, vaults, items, cwd, def_dir, tag

	if type(arg) == 'table' then
		name = arg.args and vim.trim(arg.args) or ''
	elseif type(arg) == 'string' then
		name = vim.trim(arg)
	else
		name = ''
	end

	vaults = list_vaults()
	if name ~= '' then
		for _, v in ipairs(vaults) do
			if v.name:lower() == name:lower() or v.path == name then
				open_vault(v.path)
				return
			end
		end
		create_vault(name)
		return
	end

	cwd = vim.fs.normalize(vim.fn.getcwd())
	def_dir = default_vault_dir()
	items = {
		{ label = '+ New vault in default dir (' .. def_dir .. ')', action = 'new_default' },
		{ label = '+ Init vault in working dir (' .. cwd .. ')', action = 'init_cwd' },
	}

	for _, v in ipairs(vaults) do
		tag = (v.path == cwd) and ' [cwd]' or ''
		table.insert(items, {
			label = v.name .. tag .. '  (' .. v.path .. ')',
			vault = v,
			action = 'open',
		})
	end

	vim.ui.select(items, {
		prompt = 'Miwiki Vaults:',
		format_item = function(item)
			return item.label
		end,
	}, function(choice)
		if not choice then
			return
		end
		if choice.action == 'new_default' then
			create_vault()
		elseif choice.action == 'init_cwd' then
			init_cwd_vault()
		elseif choice.action == 'open' then
			open_vault(choice.vault.path)
		end
	end)
end

local function complete_vaults(lead)
	local vaults, matches

	vaults = list_vaults()
	matches = {}
	lead = (lead or ''):lower()
	for _, v in ipairs(vaults) do
		if lead == '' or v.name:lower():find(lead, 1, true) then
			table.insert(matches, v.name)
		end
	end
	table.sort(matches)
	return matches
end

_G.miwiki_complete_vaults = complete_vaults

local M = {
	follow_or_create = follow_or_create,
	follow_or_create_visual = follow_or_create_visual,
	smart_action = smart_action,
	move_to_note = move_to_note,
	complete_notes = complete_notes,
	complete_vaults = complete_vaults,
	choose_vault = choose_vault,
	create_vault = create_vault,
	init_cwd_vault = init_cwd_vault,
	open_vault = open_vault,
	list_vaults = list_vaults,
}

return M
